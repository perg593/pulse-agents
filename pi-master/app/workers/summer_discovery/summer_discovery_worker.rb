# frozen_string_literal: true

require "klaviyo-api-sdk"

module SummerDiscovery
  class SummerDiscoveryWorker
    include Common
    include Sidekiq::Worker
    include ClientReports::StatusLogger

    KLAVIYO_KEY_BY_QUESTION_ID = {
      24720 => "Pi_decision",
      24879 => "Pi_fosinterest",
      24880 => "Pi_campusinterest"
    }.freeze

    def perform(report_data_start_time: nil, report_data_end_time: nil)
      tagged_logger.info "Started"

      report_data_start_time ||= 1.week.ago.beginning_of_day
      report_data_end_time ||= report_data_start_time.end_of_week

      answers = Answer.where(
        question_id: KLAVIYO_KEY_BY_QUESTION_ID.keys,
        created_at: report_data_start_time..report_data_end_time
      ).includes(:submission, :possible_answer)

      tagged_logger.info "Found #{answers.count} answers"

      answers.group_by(&:submission).each do |submission, answers_for_submission|
        answers_for_submission.group_by(&:question).each do |question, answers_for_question|
          klaviyo_profile_id = extract_klaviyo_profile_id_from_submission(submission)

          if klaviyo_profile_id.blank?
            tagged_logger.info "No Klaviyo ID for submission #{submission.id}"
            next
          end

          possible_answer_ids = answers_for_question.pluck(:possible_answer_id)
          klaviyo_key = KLAVIYO_KEY_BY_QUESTION_ID[question.id]

          possible_answer_content = PossibleAnswer.where(id: possible_answer_ids).pluck(:content)

          send_to_klaviyo(klaviyo_profile_id, klaviyo_key, possible_answer_content)
        end
      end

      record_success(report_data_start_time)
    rescue StandardError => e
      tagged_logger.info "Error #{e.inspect}"
      Rollbar.error(e, "SummerDiscoveryWorker failed")

      record_failure(report_data_start_time)
    ensure
      tagged_logger.info "Finished"
    end

    # data_start_time -- the beginning of a week
    def self.delivered_as_expected?(data_start_time = 1.week.ago.beginning_of_week)
      ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
    end

    private

    def extract_klaviyo_profile_id_from_submission(submission)
      klaviyo_profile_id = submission.custom_data.try(:[], "KlaviyoID")
      klaviyo_profile_id ||= if submission.url
        Rack::Utils.parse_query(URI.parse(submission.url).query).try(:[], "KlaviyoID")
      end
    end

    def send_to_klaviyo(klaviyo_profile_id, klaviyo_key, possible_answer_content)
      KlaviyoAPI::Profiles.update_profile(
        klaviyo_profile_id,
        {
          data: {
            id: klaviyo_profile_id,
            type: "profile",
            attributes: {
              properties: {
                klaviyo_key => possible_answer_content
              }
            }
          }
        }
      )
    rescue KlaviyoAPI::ApiError => e
      raise unless JSON.parse(e.response_body).dig("errors", 0, "detail").match?(/A profile with id .* does not exist./)

      Rollbar.warning(e, "SummerDiscoveryWorker -- Invalid Klaviyo Profile ID")
    end
  end
end
