# frozen_string_literal: true

require_relative 'database/sql_helpers'

# rubocop:disable Metrics/ModuleLength, Layout/LineLength
module Rack
  module Database
    include Postgres, DatabaseNative, DatabaseFilters, DatabaseTriggers, DatabaseCustomDataTriggers, DatabaseGetters, DatabaseSetters, DatabaseDirect,
            DatabaseQuestionsAndAnswers, DatabasePresentSurvey, DatabasePresentEvent, DatabasePresentResults, DatabaseEmail, DatabasePresentPoll

    # If you update this, please update Survey#attributes_for_javascript as well so that it's in SYNC
    def surveys_columns_to_select
      [:id, :name, :survey_type, :invitation, :top_position, :bottom_position, :left_position, :right_position, :width, :background_color, :text_color, :logo,
       :inline_target_selector, :custom_css, :thank_you, :pusher_enabled, :answer_text_color, :mobile_inline_target_selector, :sdk_inline_target_selector,
       :display_all_questions, :fullscreen_margin, :invitation_button, :invitation_button_disabled, :single_page, :ignore_frequency_cap,
       :randomize_question_order, :all_at_once_empty_error_enabled, :all_at_once_submit_label, :all_at_once_error_text, :survey_locale_group_id]
    end

    # Find a survey to serve
    def get_surveys(pi_identifier, url, udid, client_key, device_type, preview_mode, pageview_count = nil, visit_count = nil, custom_data = nil)
      # Survey status 1 is "live"

      # Triggers
      #  - if there's no triggers defined - trigger all the time.
      #  - otherwise, trigger if there's at least one including triggers and no exluding triggers

      # Pageview_count and visit_count are used for triggers and come from cookies, can be nil if not set

      # Supports start at / end at
      # Sample rate
      # Excludes surveys this device already submitted

      # Device type is "desktop", "mobile" or "tablet"

      columns_to_select = surveys_columns_to_select
      sql_select        = columns_to_select.map { |c| "\"surveys\".\"#{c}\"" }.join(",")
      url               = url_without_protocol(url)
      triggering_rules  = survey_triggering_rules(preview_mode: preview_mode)
      visit_count ||= '0'

      return url if url.is_a?(Array) && url[0] == 403 # invalid url

      sql = surveys_sql(sql_select, url, pageview_count, udid, client_key, pi_identifier, triggering_rules, device_type, preview_mode)
      log sql, 'DEBUG'

      process_query(sql, udid, pi_identifier, client_key, visit_count, columns_to_select, custom_data)
    end

    def process_query(sql, udid, pi_identifier, client_key, visit_count, columns_to_select, custom_data)
      surveys = []

      postgres_execute(sql).each do |row|
        survey = {}
        next unless filter_survey(row["id"], udid, pi_identifier, client_key, custom_data)
        next unless filter_previous_answer_survey(row["id"], udid, client_key)
        next unless filter_visits(visit_count, client_key, udid, row["id"])
        next unless filter_client_key_trigger(row["client_key_presence"], client_key)

        columns_to_select.each do |column|
          # If you update this, please update Survey#attributes_for_javascript as well so that it's in SYNC
          survey[column] = [:id, :survey_type, :width].include?(column) ? row[column.to_s].to_i : row[column.to_s]
        end

        survey = populate_survey(survey, row)
        survey = populate_render_triggers(survey, row)
        survey = populate_text_on_page_trigger(survey, row)
        survey = populate_background_image(survey, row)
        survey = populate_single_page_flag(survey, row)
        survey = populate_ignore_freq_cap_flag(survey, row)
        survey = populate_display_all_at_once_setting(survey, row)
        survey = populate_personal_data_setting(survey, row)
        survey = populate_feature_flags(survey, row)

        surveys << survey
      end

      surveys
    end

    def populate_survey(survey, row)
      survey[:pulse_insights_branding]                = (row["pulse_insights_branding"] == "1")
      survey[:custom_data_snippet]                    = row["custom_data_enabled"] == "1" ? row["custom_data_snippet"] : nil
      survey[:onclose_callback_code]                  = row["onclose_callback_enabled"] == "1" ? row["onclose_callback_code"] : nil
      survey[:oncomplete_callback_code]               = row["oncomplete_callback_enabled"] == "1" ? row["oncomplete_callback_code"] : nil
      survey[:onanswer_callback_code]                 = row["onanswer_callback_enabled"] == "1" ? row["onanswer_callback_code"] : nil
      survey[:onview_callback_code]                   = row["onview_callback_enabled"] == "1" ? row["onview_callback_code"] : nil
      survey[:onclick_callback_code]                  = row["onclick_callback_enabled"] == "1" ? row["onclick_callback_code"] : nil
      survey[:inline_target_position]                 = row["inline_target_position"]
      survey[:theme_css]                              = row["theme_css"]
      survey[:survey_locale_group_id]                 = row["survey_locale_group_id"]

      survey
    end

    def populate_render_triggers(survey, row)
      survey[:render_after_x_seconds]                 = row["render_after_x_seconds"] && !row["render_after_x_seconds"].empty? ? row["render_after_x_seconds"].to_i : row["render_after_x_seconds"]
      survey[:render_after_x_seconds_enabled]         = row["render_after_x_seconds_enabled"]
      survey[:render_after_x_percent_scroll]          = row["render_after_x_percent_scroll"] && !row["render_after_x_percent_scroll"].empty? ? row["render_after_x_percent_scroll"].to_i : row["render_after_x_percent_scroll"]
      survey[:render_after_x_percent_scroll_enabled]  = row["render_after_x_percent_scroll_enabled"]
      survey[:render_after_intent_exit_enabled]       = row["render_after_intent_exit_enabled"]
      survey[:render_after_element_clicked]           = row["render_after_element_clicked"]
      survey[:render_after_element_clicked_enabled]   = row["render_after_element_clicked_enabled"]
      survey[:render_after_element_visible]           = row["render_after_element_visible"]
      survey[:render_after_element_visible_enabled]   = row["render_after_element_visible_enabled"]

      survey
    end

    def populate_single_page_flag(survey, row)
      survey[:single_page] = (row["single_page"] == "t")

      survey
    end

    def populate_ignore_freq_cap_flag(survey, row)
      survey[:ignore_frequency_cap] = (row["ignore_frequency_cap"] == "t")

      survey
    end

    def populate_text_on_page_trigger(survey, row)
      survey[:text_on_page_enabled]                   = row["text_on_page_enabled"]
      survey[:text_on_page_presence]                  = row["text_on_page_presence"]
      survey[:text_on_page_selector]                  = row["text_on_page_selector"]
      survey[:text_on_page_value]                     = row["text_on_page_value"]

      survey
    end

    def populate_background_image(survey, row)
      if row["background"] && row["background"] != ''
        survey[:background] = "https://cdn.pulseinsights.com/background/survey/#{row["id"]}/#{row["background"]}"
      elsif row["remote_background"] && row["remote_background"] != ''
        survey[:background] = row["remote_background"]
      end

      survey
    end

    # TODO: Fill in empty db values and remove this.
    def populate_display_all_at_once_setting(survey, row)
      key = "all_at_once_submit_label"
      survey[key.to_sym] = row[key].nil? || row[key].empty? ? "Submit" : row[key]

      key = "all_at_once_error_text"
      survey[key.to_sym] = row[key].nil? || row[key].empty? ? "Please fill answers" : row[key]

      survey
    end

    def populate_personal_data_setting(survey, row)
      survey[:personal_data_masking_enabled] = (row["personal_data_masking_enabled"] == "t")
      survey[:phone_number_masked]           = (row["phone_number_masked"] == "t")
      survey[:email_masked]                  = (row["email_masked"] == "t")

      survey
    end

    def populate_feature_flags(survey, row)
      survey[:custom_content_link_click_enabled] = row["custom_content_link_click_enabled"]

      survey
    end

    # rubocop:disable Metrics/MethodLength
    # TODO: Come up with a way of simplifying/removing this
    def surveys_sql(sql_select, url, pageview_count, udid, client_key, pi_identifier, triggering_rules, device_type, preview_mode)
      pageview_count ||= '0'

      <<-SQL
        SELECT surveys.*, "page_after_seconds_triggers"."render_after_x_seconds", "page_after_seconds_triggers"."render_after_x_seconds_enabled",
          "page_scroll_triggers"."render_after_x_percent_scroll", "page_scroll_triggers"."render_after_x_percent_scroll_enabled",
          "page_intent_exit_triggers"."render_after_intent_exit_enabled", "page_element_clicked_triggers"."render_after_element_clicked",
          "page_element_clicked_triggers"."render_after_element_clicked_enabled","page_element_visible_triggers"."render_after_element_visible",
          "page_element_visible_triggers"."render_after_element_visible_enabled", "text_on_page_triggers"."text_on_page_enabled",
          "text_on_page_triggers"."text_on_page_presence", "text_on_page_triggers"."text_on_page_selector", "text_on_page_triggers"."text_on_page_value",
          "themes"."css" AS theme_css, "client_key_triggers"."client_key_presence"
        FROM (
          SELECT #{sql_select}, "surveys"."theme_id", pulse_insights_branding, custom_data_enabled, custom_data_snippet, oncomplete_callback_enabled,
            oncomplete_callback_code, inline_target_position, onanswer_callback_enabled, onanswer_callback_code, onview_callback_enabled, onview_callback_code,
            cap_impressions_count, frequency_cap_enabled, frequency_cap_limit, background, remote_background, onclose_callback_enabled,
            onclose_callback_code, custom_content_link_click_enabled, personal_data_masking_enabled, phone_number_masked, email_masked,
            onclick_callback_enabled, onclick_callback_code
          FROM
          ( SELECT #{sql_select}, "surveys"."theme_id",
            "surveys"."desktop_enabled", "surveys"."mobile_enabled", "surveys"."tablet_enabled", "surveys"."inline_target_position" AS inline_target_position,
            "surveys"."refire_enabled", "surveys"."refire_time", "surveys"."refire_time_period",
            MIN("accounts"."pulse_insights_branding"::int) AS pulse_insights_branding,
            MIN("accounts"."custom_data_enabled"::int) AS custom_data_enabled,
            FIRST("accounts"."custom_data_snippet") AS custom_data_snippet,
            MIN("accounts"."oncomplete_callback_enabled"::int) AS oncomplete_callback_enabled,
            FIRST("accounts"."oncomplete_callback_code") AS oncomplete_callback_code,
            MIN("accounts"."onanswer_callback_enabled"::int) AS onanswer_callback_enabled,
            FIRST("accounts"."onanswer_callback_code") AS onanswer_callback_code,
            MIN("accounts"."onview_callback_enabled"::int) AS onview_callback_enabled,
            FIRST("accounts"."onview_callback_code") AS onview_callback_code,
            MIN("accounts"."onclose_callback_enabled"::int) AS onclose_callback_enabled,
            FIRST("accounts"."onclose_callback_code") AS onclose_callback_code,
            MIN("accounts"."onclick_callback_enabled"::int) AS onclick_callback_enabled,
            FIRST("accounts"."onclick_callback_code") AS onclick_callback_code,
            FIRST("accounts"."custom_content_link_click_enabled") AS custom_content_link_click_enabled,
            FIRST("personal_data_settings"."masking_enabled") AS personal_data_masking_enabled,
            FIRST("personal_data_settings"."phone_number_masked") AS phone_number_masked,
            FIRST("personal_data_settings"."email_masked") AS email_masked,
            COUNT("triggers"."id") AS triggers_count,
            MAX("submissions"."created_at" ) AS last_submission_created_at,
            COUNT(DISTINCT("total_including_triggers"."id")) AS total_including_triggers_count,
            COUNT(DISTINCT("including_triggers"."id")) AS including_triggers_count,
            COUNT(DISTINCT("excluding_triggers"."id")) AS excluding_triggers_count,
            COUNT(DISTINCT("pageview_triggers"."id")) AS pageview_triggers_count,
            COUNT(DISTINCT("submissions"."id")) AS device_submissions_count,
            COUNT(DISTINCT("cap_impressions"."id")) AS cap_impressions_count,
            FIRST("accounts"."frequency_cap_enabled") AS frequency_cap_enabled,
            FIRST("accounts"."frequency_cap_limit") AS frequency_cap_limit,
            "surveys"."background" AS background,
            "surveys"."remote_background" AS remote_background,
            COUNT(DISTINCT("total_geo_triggers"."id")) AS total_geo_triggers_count,
            COUNT(DISTINCT("geo_triggers"."id")) AS geo_triggers_count
            FROM "surveys"
            INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
            INNER JOIN "personal_data_settings" ON "personal_data_settings"."account_id" = "accounts"."id"
            LEFT OUTER JOIN "triggers" ON "triggers"."survey_id" = "surveys"."id" AND "triggers"."device_data_matcher" IS NULL
            LEFT OUTER JOIN "triggers" AS "total_including_triggers" ON "total_including_triggers"."survey_id" = "surveys"."id" AND "total_including_triggers"."excluded" = 'f' AND
                  "total_including_triggers"."type_cd" IN ('RegexpTrigger', 'UrlTrigger', 'UrlMatchesTrigger', 'PseudoEventTrigger') AND "total_including_triggers"."device_data_matcher" IS NULL
            LEFT OUTER JOIN "triggers" AS "including_triggers" ON "including_triggers"."survey_id" = "surveys"."id" AND "including_triggers"."excluded" = 'f' AND "including_triggers"."type_cd" IN ('RegexpTrigger', 'UrlTrigger', 'UrlMatchesTrigger', 'PseudoEventTrigger') AND
                  (("including_triggers"."url" IS NULL AND  '#{PG::Connection.escape(url)}' ~* "including_triggers"."regexp") OR
                   ('#{PG::Connection.escape(url)}' LIKE ('%' || "including_triggers"."url" || '%') AND "including_triggers"."regexp" IS NULL) OR
                   ("including_triggers"."url" IS NULL AND "including_triggers"."regexp" IS NULL AND '#{PG::Connection.escape(url)}' ~* ('^' || "including_triggers"."url_matches" || '(\\/)?' || '(\\?.+)?' || '$' ))
                   ) AND "including_triggers"."device_data_matcher" IS NULL
            LEFT OUTER JOIN "triggers" AS "excluding_triggers" ON "excluding_triggers"."survey_id" = "surveys"."id" AND "excluding_triggers"."excluded" = 't' AND "excluding_triggers"."type_cd" IN ('RegexpTrigger', 'UrlTrigger', 'UrlMatchesTrigger', 'PseudoEventTrigger') AND
                  (("excluding_triggers"."url" IS NULL AND '#{PG::Connection.escape(url)}' ~* "excluding_triggers"."regexp") OR
                   ('#{PG::Connection.escape(url)}' LIKE ('%' || "excluding_triggers"."url" || '%') AND "excluding_triggers"."regexp" IS NULL) OR
                   ("excluding_triggers"."url" IS NULL AND "excluding_triggers"."regexp" IS NULL AND '#{PG::Connection.escape(url)}' ~* ('^' || "excluding_triggers"."url_matches" || '(\\/)?' || '(\\?.+)?' || '$' ))
                   ) AND "including_triggers"."device_data_matcher" IS NULL
            LEFT OUTER JOIN "triggers" AS "pageview_triggers" ON "pageview_triggers"."survey_id" = "surveys"."id" AND "pageview_triggers"."type_cd" = 'PageviewTrigger' AND
                  #{pageview_count || '0'}::integer < "pageview_triggers"."pageviews_count" AND "including_triggers"."device_data_matcher" IS NULL
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
          WHERE ("surveys"."triggers_count" = 0 OR (("surveys"."total_including_triggers_count" = 0 OR "surveys"."including_triggers_count" != 0) AND
                "surveys"."excluding_triggers_count" = 0 AND "surveys"."pageview_triggers_count" = 0)) AND
                ("surveys"."device_submissions_count" = 0 OR ("surveys"."refire_enabled" IS TRUE AND "surveys"."last_submission_created_at"::timestamp +  ("surveys"."refire_time"::TEXT || ' ' || "surveys"."refire_time_period"::TEXT )::INTERVAL <= NOW() AT TIME ZONE 'UTC')) AND
                #{SQLHelpers.frequency_cap_filter_sql(preview_mode)} AND
                ("surveys"."#{PG::Connection.escape(device_type)}_enabled" = 't') AND
                ("surveys"."total_geo_triggers_count" = 0 OR "surveys"."geo_triggers_count" != 0)
        ) AS "surveys"
        LEFT OUTER JOIN "themes"   ON "themes"."id" = "surveys"."theme_id"
        LEFT OUTER JOIN "triggers" AS "page_after_seconds_triggers" ON "page_after_seconds_triggers"."survey_id" = "surveys"."id" AND "page_after_seconds_triggers"."type_cd" = 'PageAfterSecondsTrigger'
        LEFT OUTER JOIN "triggers" AS "page_scroll_triggers" ON "page_scroll_triggers"."survey_id" = "surveys"."id" AND "page_scroll_triggers"."type_cd" = 'PageScrollTrigger'
        LEFT OUTER JOIN "triggers" AS "page_intent_exit_triggers" ON "page_intent_exit_triggers"."survey_id" = "surveys"."id" AND "page_intent_exit_triggers"."type_cd" = 'PageIntentExitTrigger'
        LEFT OUTER JOIN "triggers" AS "page_element_clicked_triggers" ON "page_element_clicked_triggers"."survey_id" = "surveys"."id" AND "page_element_clicked_triggers"."type_cd" = 'PageElementClickedTrigger'
        LEFT OUTER JOIN "triggers" AS "page_element_visible_triggers" ON "page_element_visible_triggers"."survey_id" = "surveys"."id" AND "page_element_visible_triggers"."type_cd" = 'PageElementVisibleTrigger'
        LEFT OUTER JOIN "triggers" AS "text_on_page_triggers" ON "text_on_page_triggers"."survey_id" = "surveys"."id" AND "text_on_page_triggers"."type_cd"= 'TextOnPageTrigger'
        LEFT OUTER JOIN "triggers" AS "client_key_triggers" ON "client_key_triggers"."survey_id" = "surveys"."id" AND "client_key_triggers"."type_cd"= 'ClientKeyTrigger';
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
  end
end
