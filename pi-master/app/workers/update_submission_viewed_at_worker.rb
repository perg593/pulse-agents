# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class UpdateSubmissionViewedAtWorker
  include Sidekiq::Worker
  include Common

  def perform(submission_udid, viewed_at)
    submission = Submission.find_with_retry_by!(udid: submission_udid)

    return unless submission.viewed_at.blank?

    submission.update(viewed_at: [submission.created_at, viewed_at].max)
  end
end
