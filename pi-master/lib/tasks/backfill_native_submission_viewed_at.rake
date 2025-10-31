# frozen_string_literal: true

require "#{Rails.root}/lib/task_helpers/logging"

task backfill_native_submission_viewed_at: :environment do
  include Logging

  account_count = Account.count

  Account.all.each.with_index(1) do |account, index|
    tagged_logger.info "#{account.name} (#{index}/#{account_count})"

    submissions = account.submissions
    submissions = submissions.where('submissions.created_at >= ?', account.viewed_impressions_enabled_at)
    submissions = submissions.where(viewed_at: nil)
    submissions = submissions.where(mobile_type: %w(ios android)) # device_type could be nil

    submissions.joins(:answers).find_each do |submission|
      viewed_at = submission.answers.order_by(:created_at).pick(:created_at)
      submission.update(viewed_at: viewed_at)
    end
  end
end
