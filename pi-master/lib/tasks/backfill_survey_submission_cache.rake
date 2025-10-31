# frozen_string_literal: true

task backfill_survey_submission_cache: :environment do
  task_name = ARGV[0]

  logger = ActiveSupport::TaggedLogging.new(Logger.new(ENV["STD_OUT"] ? $stdout : "log/#{task_name}.log"))

  logger.info "Starting!"

  first_cache_date = Submission.order(:created_at).first.created_at.to_date
  last_cache_date = 1.day.ago.to_date

  (first_cache_date..last_cache_date).each do |cache_date|
    if SurveySubmissionCache.where(applies_to_date: cache_date).exists?
      logger.info "Cache data already exists for #{cache_date} -- skipping"

      next
    end

    logger.info "Processing for #{cache_date}"

    SurveySubmissionCacheWorker.new.perform(cache_date.beginning_of_day, cache_date.end_of_day)
  end

  logger.info "Done!"
end

task backfill_viewed_impression_cache: :environment do
  require 'logging'

  dry_run = ENV['dry_run'] == 'true'

  start_date = Date.new(2021, 10, 10) # submissions.viewed_at was added on this date
  end_date = Date.today

  (start_date..end_date).each do |date|
    tagged_logger.info "Date: #{date}"

    viewed_impressions = Submission.where.not(viewed_at: nil)
    viewed_impressions = viewed_impressions.where(created_at: date.beginning_of_day..date.end_of_day)

    viewed_impressions.group(:survey_id).count.each do |survey_id, viewed_impression_count|
      tagged_logger.info "Survey ID: #{survey_id}, Viewed Impression Count: #{viewed_impression_count}"

      unless cache = SurveySubmissionCache.where.associated(:survey).find_by(survey_id: survey_id, applies_to_date: date)
        tagged_logger.info 'Cache Record Not Found'
        next
      end

      cache.update!(viewed_impression_count: viewed_impression_count) unless dry_run
    end
  end
end
