# frozen_string_literal: true

require_relative 'sql_helpers'

# rubocop:disable Metrics/ModuleLength, Layout/LineLength
module Rack
  module DatabaseNative
    # Find a survey to serve for 'native_mobile' devices
    def get_surveys_for_native(pi_identifier, udid, preview_mode, install_days, launch_times, client_key, mobile_type, view_name = '', custom_data = nil)
      columns_to_select = surveys_columns_to_select
      sql_select = columns_to_select.map { |c| "\"surveys\".\"#{c}\"" }.join(",")
      triggering_rules = survey_triggering_rules(preview_mode: preview_mode)
      view_name = '' if view_name.nil?

      sql = get_surveys_for_native_sql(sql_select, view_name, install_days, udid, pi_identifier, triggering_rules, launch_times, client_key, mobile_type, preview_mode)

      log sql, 'DEBUG'
      surveys = []

      postgres_execute(sql).each do |row|
        survey = {}
        next unless filter_survey(row["id"], udid, pi_identifier, client_key, custom_data)
        next unless filter_previous_answer_survey(row["id"], udid, client_key)
        next unless filter_client_key_trigger(row["client_key_presence"], client_key)

        columns_to_select.each do |column|
          # If you update this, please update Survey#attributes_for_javascript as well so that it's in SYNC
          survey[column] =
            if [:id, :survey_type, :width].include?(column)
              row[column.to_s].to_i
            else
              row[column.to_s]
            end
        end

        survey = populate_native_survey(survey, row)
        survey = populate_background_image(survey, row)
        survey = populate_ignore_freq_cap_flag(survey, row)
        survey = populate_display_all_at_once_setting(survey, row)
        survey = populate_personal_data_setting(survey, row)
        survey = populate_feature_flags(survey, row)

        surveys << survey
      end

      surveys
    end

    private

    def get_surveys_for_native_sql(sql_select, view_name, install_days, udid, pi_identifier, triggering_rules, launch_times, client_key, mobile_type, preview_mode)
      <<-SQL
        SELECT #{sql_select}, pulse_insights_branding, custom_data_enabled, custom_data_snippet, onclose_callback_enabled, onclose_callback_code,
        oncomplete_callback_enabled, oncomplete_callback_code, inline_target_position, onanswer_callback_enabled, onanswer_callback_code,
        theme_native, cap_impressions_count, frequency_cap_enabled frequency_cap_limit, background, remote_background,
        page_after_seconds_triggers.render_after_x_seconds, page_after_seconds_triggers.render_after_x_seconds_enabled,
        personal_data_masking_enabled, phone_number_masked, email_masked, client_key_triggers.client_key_presence AS client_key_presence,
        sdk_widget_height, custom_content_link_click_enabled
        FROM
        ( SELECT #{sql_select},
          "surveys"."desktop_enabled",
          "surveys"."mobile_enabled",
          "surveys"."tablet_enabled",
          "surveys"."ios_enabled",
          "surveys"."android_enabled",
          "surveys"."inline_target_position" AS inline_target_position,
          "surveys"."refire_enabled", "surveys"."refire_time", "surveys"."refire_time_period",
          MIN("accounts"."pulse_insights_branding"::int) AS pulse_insights_branding,
          MIN("accounts"."custom_data_enabled"::int) AS custom_data_enabled,
          FIRST("accounts"."custom_data_snippet") AS custom_data_snippet,
          MIN("accounts"."onclose_callback_enabled"::int) AS onclose_callback_enabled,
          FIRST("accounts"."onclose_callback_code") AS onclose_callback_code,
          MIN("accounts"."oncomplete_callback_enabled"::int) AS oncomplete_callback_enabled,
          FIRST("accounts"."oncomplete_callback_code") AS oncomplete_callback_code,
          MIN("accounts"."onanswer_callback_enabled"::int) AS onanswer_callback_enabled,
          FIRST("accounts"."onanswer_callback_code") AS onanswer_callback_code,
          FIRST("personal_data_settings"."masking_enabled") AS personal_data_masking_enabled,
          FIRST("personal_data_settings"."phone_number_masked") AS phone_number_masked,
          FIRST("personal_data_settings"."email_masked") AS email_masked,
          COUNT("triggers"."id") AS triggers_count,
          MAX("submissions"."created_at" ) AS last_submission_created_at,
          COUNT(DISTINCT("total_including_triggers"."id")) AS total_including_triggers_count,
          COUNT(DISTINCT("including_triggers"."id")) AS including_triggers_count,
          COUNT(DISTINCT("excluding_triggers"."id")) AS excluding_triggers_count,
          COUNT(DISTINCT("install_triggers"."id")) AS install_triggers_count,
          COUNT(DISTINCT("launch_triggers"."id")) AS launch_triggers_count,
          COUNT(DISTINCT("submissions"."id")) AS device_submissions_count,
          FIRST("sdk_themes"."native_content") AS theme_native,
          COUNT(DISTINCT("cap_impressions"."id")) AS cap_impressions_count,
          FIRST("accounts"."frequency_cap_enabled") AS frequency_cap_enabled,
          FIRST("accounts"."frequency_cap_limit") AS frequency_cap_limit,
          FIRST("accounts"."custom_content_link_click_enabled") AS custom_content_link_click_enabled,
          "surveys"."background" AS background,
          "surveys"."remote_background" AS remote_background,
          "surveys"."sdk_widget_height" AS sdk_widget_height,
          COUNT(DISTINCT("total_geo_triggers"."id")) AS total_geo_triggers_count,
          COUNT(DISTINCT("geo_triggers"."id")) AS geo_triggers_count
          FROM "surveys"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          INNER JOIN "personal_data_settings" ON "personal_data_settings"."account_id" = "accounts"."id"
          LEFT OUTER JOIN "themes" ON "themes"."id" = "surveys"."theme_id"
          LEFT OUTER JOIN "themes" AS "sdk_themes" ON "sdk_themes"."id" = "surveys"."sdk_theme_id"
          LEFT OUTER JOIN "triggers" ON "triggers"."survey_id" = "surveys"."id" AND "triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "total_including_triggers" ON "total_including_triggers"."survey_id" = "surveys"."id" AND "total_including_triggers"."excluded" = 'f' AND
                "total_including_triggers"."type_cd" IN ('MobilePageviewTrigger', 'MobileRegexpTrigger') AND "total_including_triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "including_triggers" ON "including_triggers"."survey_id" = "surveys"."id" AND "including_triggers"."excluded" = 'f' AND "including_triggers"."type_cd" IN ('MobilePageviewTrigger', 'MobileRegexpTrigger') AND
                (("including_triggers"."mobile_pageview" IS NULL AND '#{PG::Connection.escape(view_name)}' ~* "including_triggers"."mobile_regexp") OR
                ('#{PG::Connection.escape(view_name)}' LIKE ('%' || "including_triggers"."mobile_pageview" || '%') AND "including_triggers"."mobile_regexp" IS NULL)) AND "including_triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "excluding_triggers" ON "excluding_triggers"."survey_id" = "surveys"."id" AND "excluding_triggers"."excluded" = 't' AND "excluding_triggers"."type_cd" IN ('MobilePageviewTrigger', 'MobileRegexpTrigger') AND
                (("excluding_triggers"."mobile_pageview" IS NULL AND '#{PG::Connection.escape(view_name)}' ~* "excluding_triggers"."mobile_regexp") OR
                 ('#{PG::Connection.escape(view_name)}' LIKE ('%' || "excluding_triggers"."mobile_pageview" || '%') AND "excluding_triggers"."mobile_regexp" IS NULL)) AND "including_triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "install_triggers" ON "install_triggers"."survey_id" = "surveys"."id" AND "install_triggers"."type_cd" = 'MobileInstallTrigger' AND
                #{install_days || '0'}::integer < "install_triggers"."mobile_days_installed" AND "including_triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "launch_triggers" ON "launch_triggers"."survey_id" = "surveys"."id" AND "launch_triggers"."type_cd" = 'MobileLaunchTrigger' AND
                #{launch_times || '0'}::integer < "launch_triggers"."mobile_launch_times" AND "including_triggers"."device_data_matcher" IS NULL
          LEFT OUTER JOIN "triggers" AS "total_geo_triggers" ON "total_geo_triggers"."survey_id" = "surveys"."id" AND "total_geo_triggers"."type_cd" = 'GeoTrigger'
          LEFT OUTER JOIN "triggers" AS "geo_triggers" ON "geo_triggers"."survey_id" = "surveys"."id" AND "geo_triggers"."type_cd" = 'GeoTrigger' AND
                '#{PG::Connection.escape(@country)}' = "geo_triggers"."geo_country" AND
                ("geo_triggers"."geo_state_or_dma" = '' OR ('#{PG::Connection.escape(@state)}' = "geo_triggers"."geo_state_or_dma" OR '#{PG::Connection.escape(@metro_code)}' = "geo_triggers"."geo_state_or_dma"))
          #{join_devices(udid, client_key)}
          LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id" AND "submissions"."answers_count" != 0
          #{SQLHelpers.frequency_cap_join_sql}
          WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND
                #{triggering_rules} AND "surveys"."id" NOT IN (
                  SELECT "surveys"."id" FROM surveys
                  INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
                  LEFT OUTER JOIN "devices" ON "devices"."udid" = '#{PG::Connection.escape(udid)}'
                  LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id"
                  WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND ("surveys"."stop_showing_without_answer" IS TRUE AND "submissions"."closed_by_user" IS TRUE AND #{preview_mode ? 'FALSE' : 'TRUE'})
                )
          GROUP BY "surveys"."id"
        ) AS "surveys"
        LEFT OUTER JOIN "triggers" AS "page_after_seconds_triggers" ON "page_after_seconds_triggers"."survey_id" = "surveys"."id" AND "page_after_seconds_triggers"."type_cd" = 'PageAfterSecondsTrigger'
        LEFT OUTER JOIN "triggers" AS "client_key_triggers" ON "client_key_triggers"."survey_id" = "surveys"."id" AND "client_key_triggers"."type_cd"= 'ClientKeyTrigger'
        WHERE ("surveys"."triggers_count" = 0 OR (("surveys"."total_including_triggers_count" = 0 OR "surveys"."including_triggers_count" != 0) AND
              "surveys"."excluding_triggers_count" = 0 AND "surveys"."install_triggers_count" = 0 AND "surveys"."launch_triggers_count" = 0)) AND
              ("surveys"."device_submissions_count" = 0 OR ("surveys"."refire_enabled" IS TRUE AND "surveys"."last_submission_created_at"::timestamp +  ("surveys"."refire_time"::TEXT || ' ' || "surveys"."refire_time_period"::TEXT )::INTERVAL <= NOW() AT TIME ZONE 'UTC')) AND
              #{SQLHelpers.ios_android_filter_sql(mobile_type)} AND
              ("surveys"."total_geo_triggers_count" = 0 OR "surveys"."geo_triggers_count" != 0) AND
              #{SQLHelpers.frequency_cap_filter_sql(preview_mode)};
      SQL
    end

    def join_devices(udid, client_key)
      if client_key
        <<-SQL
          LEFT OUTER JOIN "devices" ON "devices"."client_key" = '#{PG::Connection.escape(client_key)}' OR "devices"."udid" = '#{PG::Connection.escape(udid)}'
        SQL
      else
        <<-SQL
          LEFT OUTER JOIN "devices" ON "devices"."udid" = '#{PG::Connection.escape(udid)}'
        SQL
      end
    end

    def populate_native_survey(survey, row)
      survey[:pulse_insights_branding]        = (row["pulse_insights_branding"] == '1')
      survey[:custom_data_snippet]            = row["custom_data_enabled"] == '1' ? row["custom_data_snippet"] : nil
      survey[:onclose_callback_code]          = row["onclose_callback_enabled"] == '1' ? row["onclose_callback_code"] : nil
      survey[:oncomplete_callback_code]       = row["oncomplete_callback_enabled"] == '1' ? row["oncomplete_callback_code"] : nil
      survey[:onanswer_callback_code]         = row["onanswer_callback_enabled"] == '1' ? row["onanswer_callback_code"] : nil
      survey[:inline_target_position]         = row["inline_target_position"]
      survey[:theme_native]                   = load_theme_native(row["theme_native"])
      survey[:render_after_x_seconds]         = row["render_after_x_seconds"] && !row["render_after_x_seconds"].empty? ? row["render_after_x_seconds"].to_i : row["render_after_x_seconds"]
      survey[:render_after_x_seconds_enabled] = row["render_after_x_seconds_enabled"]
      survey[:sdk_widget_height]              = %w(0 4).include?(row["survey_type"]) ? 0 : row["sdk_widget_height"].to_i # docked_widget and fullscreen
      survey
    end

    def load_theme_native(json)
      # https://www.rubydoc.info/gems/rubocop/RuboCop/Cop/Security/JSONLoad
      JSON.parse(json, quirks_mode: true)
    rescue
      nil
    end
  end
end
