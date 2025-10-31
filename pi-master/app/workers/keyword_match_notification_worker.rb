# frozen_string_literal: true
#
require File.join(File.dirname(__FILE__), 'common')

class KeywordMatchNotificationWorker
  include Sidekiq::Worker
  include Common

  # One job per one answer id leads to simpler error handling thanks to not having to identify which ids have been processed and which haven't.
  def perform(answer_id)
    tagged_logger.info "Answer ID: #{answer_id}"

    answer = Answer.find_with_retry_by!(id: answer_id)

    tagged_logger.error 'Empty Answer' and return unless answer_text = answer.text_of_response

    question = answer.question

    matched_automations = question.survey.account.automations.enabled.send_email.select do |automation|
      automation.match?(answer_text, question.id)
    end
    tagged_logger.info "Matched automations: #{matched_automations.pluck(:id)}"

    matched_automations.each(&:update_trigger_stats)

    emails = matched_automations.map(&:emails).flatten.uniq
    tagged_logger.info "Emails: #{emails}"
    UserMailer.automation_triggered(emails, question.survey.name, question.content, matched_automations.map(&:name), answer_text).deliver_now if emails.present?
  rescue => e
    tagged_logger.error e
    Rollbar.error e
  end
end
