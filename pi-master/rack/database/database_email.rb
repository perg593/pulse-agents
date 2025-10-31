# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
# There is a lot of verbose work to be done

module Rack
  module DatabaseEmail
    def get_device_by_client_key(client_key)
      device = {}

      sql = <<-SQL
        SELECT "devices"."id", "devices"."udid"
          FROM "devices"
          WHERE "devices"."client_key" = '#{PG::Connection.escape(client_key)}'
      SQL

      postgres_execute(sql).each do |row|
        device[:id] = row["id"]
        device[:udid] = row["udid"]
      end

      device
    end

    # There's a lot of precedence for this naming convention
    def get_questions_and_possible_answers_for_email_sql(identifier, survey)
      <<-SQL
        SELECT "questions"."id" AS question_id, "questions"."content" AS question_content, "questions"."position" AS question_position, "questions"."question_type" AS question_type, "questions"."submit_label" as question_submit_label, "questions"."max_length", "questions"."hint_text" AS hint_text, "questions"."randomize",
          "possible_answers"."id" AS possible_answer_id, "possible_answers"."content" AS possible_answer_content, "possible_answers"."next_question_id" AS possible_answer_next_question_id, "possible_answers"."position" AS possible_answer_position,
          "answer_images"."id" AS answer_image_id, "answer_images"."image" AS answer_image_name, "questions"."single_choice_default_label", "questions"."error_text"
          FROM "questions"
          INNER JOIN "surveys" ON "surveys"."id" = "questions"."survey_id"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          LEFT OUTER JOIN "possible_answers" ON "possible_answers"."question_id" = "questions"."id"
          LEFT OUTER JOIN "answer_images" ON "possible_answers"."answer_image_id" = "answer_images"."id"
          WHERE "accounts"."identifier" = '#{PG::Connection.escape(identifier)}'
            AND surveys.id = '#{PG::Connection.escape(survey[:id])}'
            ORDER BY question_position, possible_answer_position
      SQL
    end

    def get_questions_and_possible_answers_for_email(identifier, survey)
      questions_and_possible_answers = []

      postgres_execute(get_questions_and_possible_answers_for_email_sql(identifier, survey)).each do |row|
        unless current_question = questions_and_possible_answers.detect { |q_and_as| q_and_as[:question_id] == row["question_id"] }
          current_question = {
            question_id: row["question_id"],
            content: row["question_content"],
            possible_answers: [],
            randomize: row["randomize"]
          }

          questions_and_possible_answers << current_question
        end

        possible_answer = {
          possible_answer_id: row["possible_answer_id"],
          content: row["possible_answer_content"],
          next_question_id: row["possible_answer_next_question_id"]
        }

        image_url = image_url(row["answer_image_id"], row["answer_image_name"])
        image_url = "https:#{image_url}" if image_url && !URI(image_url).scheme # Gmail requires a scheme
        possible_answer[:image_url] = image_url if image_url

        possible_answer = fill_possible_answer_per_question_type(possible_answer, row)

        current_question[:possible_answers] << possible_answer
      end

      randomize_possible_answers(questions_and_possible_answers)
    end

    def get_surveys_for_email_sql(identifier, client_key, survey_id = nil, udid = nil)
      # Date, status, and sample_rate filter
      triggering_rules = survey_triggering_rules(preview_mode: false)

      survey_columns = %w(id invitation invitation_button invitation_button_disabled thank_you)
      sql_select = survey_columns.map { |c| "\"surveys\".\"#{c}\"" }.join(",")

      <<-SQL
        SELECT surveys.*
        FROM
        ( SELECT #{sql_select},
          "surveys"."refire_enabled", "surveys"."refire_time", "surveys"."refire_time_period",
          MAX("submissions"."created_at" ) AS last_submission_created_at,
          COUNT(DISTINCT("submissions"."id")) AS device_submissions_count,
          FIRST("personal_data_settings"."masking_enabled") AS personal_data_masking_enabled,
          FIRST("personal_data_settings"."phone_number_masked") AS phone_number_masked,
          FIRST("personal_data_settings"."email_masked") AS email_masked
          FROM "surveys"
          INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
          INNER JOIN "personal_data_settings" ON "personal_data_settings"."account_id" = "accounts"."id"
          LEFT OUTER JOIN "devices" ON "devices"."client_key" = '#{PG::Connection.escape(client_key)}' #{"OR \"devices\".\"udid\" = '#{PG::Connection.escape(udid)}'" if udid}
          LEFT OUTER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id" AND "submissions"."device_id" = "devices"."id" AND "submissions"."answers_count" != 0
          WHERE "accounts"."identifier" = '#{PG::Connection.escape(identifier)}'
          AND #{triggering_rules}
          AND "surveys"."email_enabled" IS TRUE
          GROUP BY "surveys"."id"
        ) AS "surveys"
          WHERE ("surveys"."device_submissions_count" = 0 OR ("surveys"."refire_enabled" IS TRUE AND "surveys"."last_submission_created_at"::timestamp +  ("surveys"."refire_time"::TEXT || ' ' || "surveys"."refire_time_period"::TEXT )::INTERVAL <= NOW() AT TIME ZONE 'UTC'))
          #{" AND surveys.id = '#{PG::Connection.escape(survey_id)}'" if survey_id}
          ;
      SQL
    end

    def get_surveys_for_email(identifier, client_key, udid, survey_id = nil, custom_data = nil)
      surveys = []

      postgres_execute(get_surveys_for_email_sql(identifier, client_key, survey_id, udid)).each do |row|
        next unless filter_survey(row["id"], udid, identifier, client_key, custom_data)
        next unless filter_previous_answer_survey(row["id"], udid, client_key)

        survey = {
          id: row["id"],
          invitation: row["invitation"],
          invitation_button: row["invitation_button"],
          invitation_button_disabled: row["invitation_button_disabled"],
          thank_you_message: row["thank_you"],
          personal_data_masking_enabled: (row["personal_data_masking_enabled"] == "t"),
          phone_number_masked:           (row["phone_number_masked"] == "t"),
          email_masked:                  (row["email_masked"] == "t")
        }

        surveys << survey
      end

      surveys
    end

    private

    def fill_possible_answer_per_question_type(possible_answer, row)
      case row["question_type"].to_i
      when 0 # single choice question
        possible_answer[:single_choice_default_label] = single_choice_default_label(row)
      when 1 # free text question
        possible_answer[:is_free_text_question] = true
        possible_answer[:question_button_label] = row["question_submit_label"]
        possible_answer[:max_length] = row["max_length"]
        possible_answer[:hint_text] = row["hint_text"]
        possible_answer[:error_text] = row["error_text"]
      end

      possible_answer
    end

    def randomize_possible_answers(questions_and_possible_answers)
      questions_and_possible_answers.each do |question_and_possible_answers|
        case question_and_possible_answers[:randomize]
        when "0"
          question_and_possible_answers[:possible_answers].shuffle!
        when "1"
          last_possible_answer = question_and_possible_answers[:possible_answers].pop
          question_and_possible_answers[:possible_answers].shuffle!
          question_and_possible_answers[:possible_answers] << last_possible_answer if last_possible_answer
        end

        question_and_possible_answers.delete(:randomize)
      end

      questions_and_possible_answers
    end
  end
end
