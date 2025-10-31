# frozen_string_literal: true

module AIOutlineGeneration
  module DataProviders
    class SurveyDataProvider < Base
      def call
        {
          answer_count: filtered_answers.count,
          question_count: survey.questions.count,
          devices_data: limited_devices_data
        }
      end

      private

      def filtered_answers
        Answer.filtered_answers(survey.answers, filters: job.filters)
      end

      def limited_devices_data
        sumission_device_data.first(10) # Limit for token management
      end

      def sumission_device_data
        job.submissions.map { |submission| submission_device_data(submission) }
      end

      def submission_device_data(submission)
        device = submission.device
        first_answer = submission.answers.includes(:question, :possible_answer, :tags).first

        build_submission_data_hash(submission, device, first_answer)
      end

      def build_submission_data_hash(submission, device, first_answer)
        base_submission_data(submission, device).
          merge(answer_data(first_answer)).
          merge(device_specific_data(device))
      end

      def base_submission_data(submission, device)
        {
          'udid' => device&.udid,
          'device_type' => submission.device_type,
          'client_key' => device&.client_key,
          'date' => submission.created_at.strftime('%m/%d/%Y'),
          'time' => submission.created_at.strftime('%H:%M:%S'),
          'survey_name' => submission.survey.name,
          'survey_id' => submission.survey.id,
          'pageview_count' => submission.pageview_count,
          'visit_count' => submission.visit_count,
          'url' => submission.url,
          'view_name' => submission.view_name,
          'ip_address' => submission.ip_address,
          'pseudo_event' => submission.pseudo_event,
          'custom_data' => submission.custom_data,
          'user_agent' => submission.user_agent,
          'os' => submission.os,
          'browser' => submission.browser,
          'browser_version' => submission.browser_version,
          'channel' => submission.channel,
          'previous_surveys' => submission.previous_surveys
        }
      end

      def answer_data(first_answer)
        {
          'question_content' => first_answer&.question&.content,
          'question_id' => first_answer&.question_id,
          'response_id' => first_answer&.id,
          'translated_response' => first_answer&.translated_answer,
          'possible_answer_id' => first_answer&.possible_answer_id,
          'response' => first_answer&.text_of_response,
          'tags' => first_answer&.tags&.pluck(:name)&.join(', ')
        }
      end

      def device_specific_data(device)
        {
          'device_data' => device&.device_datas&.last&.device_data
        }
      end
    end
  end
end
