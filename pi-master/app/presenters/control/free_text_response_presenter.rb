# frozen_string_literal: true

module Control
  class FreeTextResponsePresenter
    def initialize(free_text_question, autotag_enabled: false, filters: {})
      @autotag_enabled = autotag_enabled
      @question = free_text_question
      @filters = filters
    end

    def props
      {
        "autotagEnabled" => @autotag_enabled,
        "question" => question,
        "tagOptions" => tags,
        "tableData" => text_response_table_data,
        "surveyId" => @question.survey_id
      }
    end

    private

    def question
      {
        "autotagEnabled" => @question.tag_automation_worker_enabled,
        "content" => @question.content,
        "id" => @question.id
      }
    end

    def text_response_table_data
      raw_data = ActiveRecord::Base.connection.execute(text_responses_sql)

      process_text_responses(raw_data)
    end

    def text_responses_sql
      <<-SQL
        SELECT  answers.id AS id,
                TO_CHAR(answers.created_at, 'MM/DD/YYYY HH24:MI:SS') AS "createdAt",
                #{device_data_sql} "deviceData",
                #{tag_json_object_sql} "appliedTags",
                answers.text_answer AS "textResponse",
                submissions.id AS submission_id,
                submissions.url AS "completionUrl",
                submissions.device_type AS "deviceType",
                submissions.custom_data AS "customData",
                submissions.survey_id AS survey_id,
                answers.translated_answer AS translation,
                CASE
                  WHEN answers.sentiment IS NULL THEN ''
                  WHEN answers.sentiment ->> 'score' IS NULL THEN ''
                  WHEN answers.sentiment ->> 'magnitude' IS NULL THEN ''
                  WHEN (answers.sentiment ->> 'score')::DECIMAL >= 0.5 AND (answers.sentiment ->> 'magnitude')::DECIMAL >= 0.4 THEN 'Very Positive'
                  WHEN (answers.sentiment ->> 'score')::DECIMAL >= 0.5 AND (answers.sentiment ->> 'magnitude')::DECIMAL < 0.4 THEN 'Positive'
                  WHEN (answers.sentiment ->> 'score')::DECIMAL <= -0.5 AND (answers.sentiment ->> 'magnitude')::DECIMAL >= 0.4 THEN 'Very Negative'
                  WHEN (answers.sentiment ->> 'score')::DECIMAL <= -0.5 AND (answers.sentiment ->> 'magnitude')::DECIMAL < 0.4 THEN 'Negative'
                  ELSE 'Neutral'
                END sentiment
        FROM "answers"
        LEFT JOIN submissions ON submissions.id = answers.submission_id
        LEFT JOIN applied_tags ON answers.id = applied_tags.answer_id
        LEFT JOIN devices ON submissions.device_id = devices.id
        LEFT JOIN device_data ON devices.id = device_data.device_id
        LEFT JOIN tags ON applied_tags.tag_id = tags.id
        LEFT JOIN tag_automation_jobs ON applied_tags.tag_automation_job_id = tag_automation_jobs.id
        WHERE "answers"."question_id" = #{@question.id}
          AND #{Submission.submissions_date_filter_sql(@filters[:date_range])}
          AND #{Submission.submissions_device_filter_sql(@filters[:device_types])}
          AND #{Submission.submissions_completion_url_filter_sql(@filters[:completion_urls])}
          AND #{Submission.submission_possible_answer_id_filter_sql(@filters[:possible_answer_id])}
          AND #{Submission.submissions_pageview_count_filter_sql(@filters[:pageview_count])}
          AND #{Submission.submissions_visit_count_filter_sql(@filters[:visit_count])}
        GROUP BY answers.id, submissions.id
        ORDER BY answers.id
        --LIMIT 20 -- DEBUGGING
      SQL
    end

    def device_data_sql
      <<-SQL
        COALESCE(json_agg(device_data.device_data) FILTER (WHERE device_data.id IS NOT NULL), '[]')
      SQL
    end

    def tag_json_object_sql
      <<-SQL
        COALESCE(json_agg(json_build_object(
          'appliedTagId', applied_tags.id,
          'tagId', applied_tags.tag_id,
          'tagColor', tags.color,
          'tagApproved', #{tag_is_manual_or_approved_sql},
          'text', tags.name ) ORDER BY tags.name) FILTER
          (WHERE applied_tags.id IS NOT NULL AND tags.name != '#{Tag::AUTOMATION_PLACEHOLDER_NAME}'), '[]')
      SQL
    end

    def tag_is_manual_or_approved_sql
      <<-SQL
        CASE
          WHEN tag_automation_jobs.id IS NULL THEN TRUE
          WHEN applied_tags.is_good_automation THEN TRUE
          ELSE FALSE
        END
      SQL
    end

    def process_text_responses(raw_data)
      relevant_keys = %w(id createdAt completionUrl translation sentiment deviceType customData deviceData appliedTags textResponse)

      raw_data.map do |answer|
        data = answer.slice(*relevant_keys)
        data["appliedTags"] = JSON.parse(data["appliedTags"])
        data
      end
    end

    def tags
      @question.tags.order(:name).map do |tag|
        {
          "id" => tag.id,
          "text" => tag.name,
          "color" => tag.color
        }
      end
    end

    # Troubleshooting only
    #
    # This is for testing how much data the front end can handle
    # Use this when you don't have enough data in your db
    # def dummy_data
    #   applied_tags = [{
    #     "tagId" => (rand * 1000).to_i,
    #     "text" => FFaker::Lorem.word,
    #     "tagApproved" => true
    #   }]
    #
    #   [
    #     {
    #       "id" => (rand * 1000).to_i,
    #       "textResponse" => FFaker::Lorem.phrase,
    #       "createdAt" => Time.current.strftime("%m/%d/%Y %X"),
    #       "completionUrl" => FFaker::Internet.http_url,
    #       "translation" => FFaker::Lorem.phrase,
    #       "sentiment" => "Very positive",
    #       "deviceType" => "Mobile",
    #       "customData" => "{ test => data}",
    #       "deviceData" => "{ device  => data}",
    #       "appliedTags" => applied_tags
    #     }
    #   ] * 220_000
    # end
  end
end
