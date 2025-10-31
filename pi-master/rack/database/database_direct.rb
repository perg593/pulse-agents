# frozen_string_literal: true

require_relative 'sql_helpers'

# rubocop:disable Metrics/ModuleLength
module Rack
  module DatabaseDirect
    ################
    # DIRECT SERVE #
    ################

    # Find a survey to serve (Server to Server API call, will also render questions and possible_answers)
    def get_surveys_direct(pi_identifier, udid, client_key, preview_mode, custom_data = nil)
      surveys = []
      columns_to_select = surveys_columns_to_select
      sql_select = columns_to_select.map { |c| "\"surveys\".\"#{c}\"" }.join(",")
      triggering_rules = survey_triggering_rules(preview_mode: false)

      sql = surveys_direct_sql(sql_select, udid, client_key, pi_identifier, triggering_rules, preview_mode)
      log sql, 'DEBUG'

      postgres_execute(sql).each do |row|
        survey = {}
        next unless filter_survey(row["id"], udid, pi_identifier, client_key, custom_data)
        next unless filter_previous_answer_survey(row["id"], udid, client_key)

        columns_to_select.each do |column|
          # If you update this, please update Survey#attributes_for_javascript as well so that it's in SYNC
          survey[column] = if [:id, :survey_type, :width].include?(column)
            row[column.to_s].to_i
          else
            row[column.to_s]
          end
        end

        survey = populate_direct_serve_survey(survey, row)
        survey = populate_background_image(survey, row)
        survey = populate_display_all_at_once_setting(survey, row)
        survey = populate_personal_data_setting(survey, row)

        surveys << survey
      end

      surveys
    end

    def surveys_direct_sql(sql_select, udid, client_key, pi_identifier, triggering_rules, preview_mode)
      <<-SQL
        SELECT #{sql_select}, pulse_insights_branding, custom_data_enabled, custom_data_snippet, onclose_callback_enabled, onclose_callback_code,
          oncomplete_callback_enabled, oncomplete_callback_code, inline_target_position, cap_impressions_count,
          onanswer_callback_enabled, onanswer_callback_code, onview_callback_enabled, onview_callback_code, theme_css,
          frequency_cap_enabled, frequency_cap_limit, background, remote_background, personal_data_masking_enabled,
          phone_number_masked, email_masked, onclick_callback_enabled, onclick_callback_code
        FROM ( SELECT #{sql_select},
          "surveys"."desktop_enabled",
          "surveys"."mobile_enabled",
          "surveys"."tablet_enabled",
          "surveys"."inline_target_position" AS inline_target_position,
          "surveys"."refire_enabled",
          "surveys"."refire_time",
          "surveys"."refire_time_period",
          MIN("accounts"."pulse_insights_branding"::int) AS pulse_insights_branding,
          MIN("accounts"."custom_data_enabled"::int) AS custom_data_enabled,
          FIRST("accounts"."custom_data_snippet") AS custom_data_snippet,
          MIN("accounts"."onclose_callback_enabled"::int) AS onclose_callback_enabled,
          FIRST("accounts"."onclose_callback_code") AS onclose_callback_code,
          MIN("accounts"."oncomplete_callback_enabled"::int) AS oncomplete_callback_enabled,
          FIRST("accounts"."oncomplete_callback_code") AS oncomplete_callback_code,
          MIN("accounts"."onanswer_callback_enabled"::int) AS onanswer_callback_enabled,
          FIRST("accounts"."onanswer_callback_code") AS onanswer_callback_code,
          MIN("accounts"."onview_callback_enabled"::int) AS onview_callback_enabled,
          FIRST("accounts"."onview_callback_code") AS onview_callback_code,
          MIN("accounts"."onclick_callback_enabled"::int) AS onclick_callback_enabled,
          FIRST("accounts"."onclick_callback_code") AS onclick_callback_code,
          FIRST("personal_data_settings"."masking_enabled") AS personal_data_masking_enabled,
          FIRST("personal_data_settings"."phone_number_masked") AS phone_number_masked,
          FIRST("personal_data_settings"."email_masked") AS email_masked,
          MAX("submissions"."created_at" ) AS last_submission_created_at,
          COUNT(DISTINCT("submissions"."id")) AS device_submissions_count,
          FIRST("themes"."css") AS theme_css,
          COUNT(DISTINCT("cap_impressions"."id")) AS cap_impressions_count,
          FIRST("accounts"."frequency_cap_enabled") AS frequency_cap_enabled,
          FIRST("accounts"."frequency_cap_limit") AS frequency_cap_limit,
          "surveys"."background" AS background,
          "surveys"."remote_background" AS remote_background
          FROM "surveys"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          INNER JOIN "personal_data_settings" ON "personal_data_settings"."account_id" = "accounts"."id"
          LEFT OUTER JOIN "themes" ON "themes"."id" = "surveys"."theme_id"
          #{join_devices(udid, client_key)}
          LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id" AND "submissions"."answers_count" != 0
          #{SQLHelpers.frequency_cap_join_sql}
          WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND
            #{triggering_rules} AND "surveys"."id" NOT IN (
              SELECT "surveys"."id" FROM surveys
              INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
              LEFT OUTER JOIN "devices" ON "devices"."udid" = '#{PG::Connection.escape(udid)}'
              LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id"
              WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND "surveys"."stop_showing_without_answer" IS TRUE AND "submissions"."closed_by_user" IS TRUE AND #{preview_mode ? 'FALSE' : 'TRUE'}
            )
          GROUP BY "surveys"."id"
        ) AS "surveys"
        WHERE ("surveys"."device_submissions_count" = 0 OR ("surveys"."refire_enabled" IS TRUE AND
          "surveys"."last_submission_created_at"::timestamp + ("surveys"."refire_time"::TEXT || ' ' || "surveys"."refire_time_period"::TEXT )::INTERVAL <= NOW() AT TIME ZONE 'UTC')) AND
          #{SQLHelpers.frequency_cap_filter_sql(preview_mode)};
      SQL
    end

    #####################
    # DIRECT SUBMISSION #
    #####################

    def question_free_text(question_id)
      sql = <<-SQL
        SELECT "questions"."question_type" FROM "questions" WHERE "questions"."id"=#{PG::Connection.escape(question_id.to_s).to_i};
      SQL

      log sql, 'DEBUG'

      # Return true if the question_type is equal to 1
      return unless row = postgres_execute(sql).first

      row["question_type"] == "1"
    end

    def get_survey_with_question(question_id)
      sql = <<-SQL
        SELECT "surveys"."id" FROM "surveys" INNER JOIN "questions" ON "questions"."survey_id" = "surveys"."id" WHERE "questions"."id"=#{PG::Connection.escape(question_id.to_s).to_i};
      SQL

      log sql, 'DEBUG'

      return unless row = postgres_execute(sql).first

      { id: row["id"] }
    end

    def get_survey_with_question_and_rules(question_id, preview_mode)
      triggering_rules = survey_triggering_rules(direct_submission: true, preview_mode: preview_mode)

      sql = <<-SQL
        SELECT "surveys"."id" FROM "surveys"
          INNER JOIN "questions" ON "questions"."survey_id" = "surveys"."id"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          WHERE "accounts"."enabled" IS TRUE AND "questions"."id"=#{PG::Connection.escape(question_id.to_s).to_i} AND #{triggering_rules};
      SQL

      log sql, 'DEBUG'

      return unless row = postgres_execute(sql).first

      { id: row["id"] }
    end

    private

    def populate_direct_serve_survey(survey, row)
      survey[:pulse_insights_branding]       = (row["pulse_insights_branding"] == "1")
      survey[:custom_data_snippet]           = row["custom_data_enabled"] == "1" ? row["custom_data_snippet"] : nil
      survey[:onclose_callback_code]         = row["onclose_callback_enabled"] == "1" ? row["onclose_callback_code"] : nil
      survey[:oncomplete_callback_code]      = row["oncomplete_callback_enabled"] == "1" ? row["oncomplete_callback_code"] : nil
      survey[:onanswer_callback_code]        = row["onanswer_callback_enabled"] == "1" ? row["onanswer_callback_code"] : nil
      survey[:onview_callback_code]          = row["onview_callback_enabled"] == "1" ? row["onview_callback_code"] : nil
      survey[:onclick_callback_code]         = row["onclick_callback_enabled"] == "1" ? row["onclick_callback_code"] : nil
      survey[:inline_target_position]        = row["inline_target_position"]
      survey[:theme_css]                     = row["theme_css"]

      survey
    end
  end
end
