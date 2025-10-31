# frozen_string_literal: true

require_relative 'sql_helpers'

module Rack
  module DatabasePresentSurvey
    # Get survey by id is used for the custom firing
    def get_survey_by_id(id, pi_identifier, udid, device_type, mobile_type = nil)
      columns_to_select = surveys_columns_to_select
      sql_select = columns_to_select.map { |c| "\"surveys\".\"#{c}\"" }.join(",")

      sql = get_survey_by_id_sql(sql_select, udid, id, pi_identifier, device_type, mobile_type)
      log sql, 'DEBUG'

      return {} unless row = postgres_execute(sql).first

      survey = {}

      columns_to_select.each { |column| survey[column] = row[column.to_s] }

      %i(id survey_type width).each { |column| survey[column] = survey[column].to_i }

      survey = populate_present_survey(survey, row)
      survey = populate_background_image(survey, row)
      survey = populate_display_all_at_once_setting(survey, row)
      survey = populate_personal_data_setting(survey, row)
      populate_theme(survey, row, device_type)
    end

    # If you update this, please update Survey#attributes_for_javascript as well so that it's in SYNC
    def populate_present_survey(survey, row)
      survey[:pulse_insights_branding]           = (row["pulse_insights_branding"] == "1")
      survey[:custom_data_snippet]               = row["custom_data_enabled"] == "1" ? row["custom_data_snippet"] : nil
      survey[:onclose_callback_code]             = row["onclose_callback_enabled"] == "1" ? row["onclose_callback_code"] : nil
      survey[:oncomplete_callback_code]          = row["oncomplete_callback_enabled"] == "1" ? row["oncomplete_callback_code"] : nil
      survey[:onanswer_callback_code]            = row["onanswer_callback_enabled"] == "1" ? row["onanswer_callback_code"] : nil
      survey[:onview_callback_code]              = row["onview_callback_enabled"] == "1" ? row["onview_callback_code"] : nil
      survey[:onclick_callback_code]             = row["onclick_callback_enabled"] == "1" ? row["onclick_callback_code"] : nil
      survey[:custom_content_link_click_enabled] = row["custom_content_link_click_enabled"]
      survey[:inline_target_position]            = row["inline_target_position"]

      survey
    end

    def populate_theme(survey, row, device_type)
      if device_type == 'native_mobile'
        survey[:theme_native] = row['theme_native'].present? ? JSON.parse(row['theme_native']): nil
      else
        survey[:theme_css] = row["theme_css"]
      end
      survey
    end

    #
    # This is basically the same request as for the generic survey request but without the triggering conditions
    # in the last WHERE sql statement but with the condition on surveys.id
    #
    # The LEFT OUTER JOINs with triggers have been removed as well
    #
    def get_survey_by_id_sql(sql_select, udid, id, pi_identifier, device_type, mobile_type)
      <<-SQL
        SELECT #{sql_select}, pulse_insights_branding, custom_data_enabled, custom_data_snippet,
        onclose_callback_enabled, onclose_callback_code, oncomplete_callback_enabled, oncomplete_callback_code, onanswer_callback_enabled, onanswer_callback_code,
        onview_callback_enabled, onview_callback_code, theme_css, theme_native, inline_target_position, background, remote_background,
        custom_content_link_click_enabled, personal_data_masking_enabled, phone_number_masked, email_masked, onclick_callback_enabled, onclick_callback_code
        FROM
        ( SELECT #{sql_select},
          "surveys"."desktop_enabled", "surveys"."mobile_enabled", "surveys"."tablet_enabled", "surveys"."ios_enabled", "surveys"."android_enabled",
          COUNT(DISTINCT("submissions"."id")) AS device_submissions_count,
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
          FIRST("accounts"."custom_content_link_click_enabled") AS custom_content_link_click_enabled,
          FIRST("personal_data_settings"."masking_enabled") AS personal_data_masking_enabled,
          FIRST("personal_data_settings"."phone_number_masked") AS phone_number_masked,
          FIRST("personal_data_settings"."email_masked") AS email_masked,
          FIRST("themes"."css") AS theme_css,
          FIRST("sdk_themes"."native_content") AS theme_native,
          "surveys"."inline_target_position" AS inline_target_position,
          "surveys"."background" AS background,
          "surveys"."remote_background" AS remote_background
          FROM "surveys"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          INNER JOIN "personal_data_settings" ON "personal_data_settings"."account_id" = "accounts"."id"
          LEFT OUTER JOIN "themes" ON "themes"."id" = "surveys"."theme_id"
          LEFT OUTER JOIN "themes" AS "sdk_themes" ON "sdk_themes"."id" = "surveys"."sdk_theme_id"
          LEFT OUTER JOIN "devices" ON "devices"."udid" = '#{PG::Connection.escape(udid)}'
          LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id"
            AND "submissions"."device_id" = "devices"."id" AND "submissions"."answers_count" != 0
          WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND
                ("surveys"."status" = 1 OR ("surveys"."status" = 0 AND '#{PG::Connection.escape(@preview_mode.to_s)}' = 'true')) AND
                ("surveys"."starts_at" IS NULL OR (("surveys"."starts_at" AT TIME ZONE 'UTC') < (NOW() AT TIME ZONE 'UTC'))) AND
                ("surveys"."ends_at" IS NULL OR (("surveys"."ends_at" AT TIME ZONE 'UTC') > (NOW() AT TIME ZONE 'UTC'))) AND
                "surveys"."id" NOT IN (
                  SELECT "surveys"."id" FROM surveys
                  INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
                  LEFT OUTER JOIN "devices" ON "devices"."udid" = '#{PG::Connection.escape(udid)}'
                  LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id"
                  WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND "surveys"."id" = #{PG::Connection.escape(id.to_s)} AND
                    ("surveys"."stop_showing_without_answer" IS TRUE AND "submissions"."closed_by_user" IS TRUE AND #{@preview_mode ? 'FALSE' : 'TRUE'})
                )
          GROUP BY "surveys"."id"
        ) AS "surveys"

        WHERE #{%w(desktop mobile tablet).include?(device_type)? "(surveys.#{PG::Connection.escape(device_type)}_enabled = 't')" : SQLHelpers.ios_android_filter_sql(mobile_type)}
          AND ("surveys"."id" = #{PG::Connection.escape(id.to_s)});
      SQL
    end
  end
end
