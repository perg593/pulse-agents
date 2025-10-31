# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class CreateCustomContentLinkClickWorker
  include Sidekiq::Worker
  include Common

  def perform(submission_udid, question_id, link_identifier, client_key, custom_data)
    tagged_logger.info 'Started'

    tagged_logger.info "Submission UDID: #{submission_udid}, Question ID: #{question_id}"
    submission = Submission.find_with_retry_by!(udid: submission_udid)
    custom_content_question = submission.survey.questions.custom_content_question.find_by!(id: question_id)

    tagged_logger.info "Link Identifier: #{link_identifier}"
    custom_content_link = custom_content_question.custom_content_links.find_by!(link_identifier: link_identifier)
    CustomContentLinkClick.create(submission: submission, custom_content_link: custom_content_link, client_key: client_key, custom_data: custom_data)
  rescue => e
    tagged_logger.error e
    Rollbar.error e, submission_udid: submission_udid, question_id: question_id, link_identifier: link_identifier
  ensure
    tagged_logger.info 'Finished'
  end
end
