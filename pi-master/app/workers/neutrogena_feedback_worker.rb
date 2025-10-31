# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'common')

class NeutrogenaFeedbackWorker
  include Sidekiq::Worker
  include Common

  # TODO: include questions identifier in window.PulseInsightObject.survey.answers
  class AnswerOrderMapper
    SATISFACTION_RATE = 0 # required to be filled in the form
    FEEDBACK = 1          # optional
    EMAIL = 2             # optional
    SUBSCRIPTION = 3      # optional
  end

  def perform(submission_udid, answers)
    tagged_logger.info 'Started'

    res = Retryable.with_retry(logger: tagged_logger) do
      RestClient::Request.execute(method: :post, url: url, payload: payload(answers), headers: header, log: tagged_logger)
    end

    tagged_logger.info "Response status: #{res['success']}, body: #{res.body}"
  rescue StandardError => e
    tagged_logger.error e
    Rollbar.error(e, 'Neutrogena Worker', submission_udid: submission_udid, answer_ids: answers.ids)
  ensure
    res ||= {}
    payload ||= {}
    log_worker_activity_to_influxdb(success: res['success'] == 'success', input: payload)
    tagged_logger.info 'Finished'
  end

  private

  def url
    Rails.application.credentials.neutrogena_endpoint
  end

  def header
    { accesskey: Rails.application.credentials.neutrogena_access_key }
  end

  def payload(answers)
    @payload ||= { pi_customer_email: answers[AnswerOrderMapper::EMAIL]&.dig('answer'),
                   pi_customer_satisfaction_rate: answers[AnswerOrderMapper::SATISFACTION_RATE]['answer_content'], # https://gitlab.ekohe.com/ekohe/pi/issues/1130#note_590947
                   pi_customer_feedback: answers[AnswerOrderMapper::FEEDBACK]&.dig('answer'),
                   pi_customer_optin: answers[AnswerOrderMapper::SUBSCRIPTION].present?
                 }
  end
end
