# frozen_string_literal: true
class SurveySubmissionCacheWorker
  include Sidekiq::Worker
  include Common

  WorkerInterval = 10.minutes.freeze

  # Runs every 10 minutes, filling in data for the last 10 minutes.
  # TODO: Provide parameters to help with manual execution
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength - Meticulous logging
  def perform(override_start_time = nil, override_end_time = nil)
    tagged_logger.info "Processing survey submission cache"

    @reported_double_counting = false
    @run_by_admin = override_start_time || override_end_time

    surveys = Survey.all
    tagged_logger.info "Processing #{surveys.count} surveys"

    # Calculate the 10 minute window rounded to the nearest 10th minute
    current_time = Time.current
    end_time = override_end_time || floor_to_nearest_10th_minute(current_time)
    start_time = override_start_time || (end_time - WorkerInterval)
    tagged_logger.info "Date range: #{start_time..end_time}"

    submission_scope = Submission.where(created_at: start_time...end_time)
    tagged_logger.info "Found #{submission_scope.count} submissions"

    impression_counts_by_survey_id = submission_scope.group(:survey_id).count
    survey_ids = impression_counts_by_survey_id.keys
    tagged_logger.info "Calculated impression counts by survey_id"

    viewed_impression_counts_by_survey_id = submission_scope.where(survey_id: survey_ids).viewed.group(:survey_id).count
    tagged_logger.info "Calculated viewed impression counts by survey_id"

    submission_counts_by_survey_id = submission_scope.where(survey_id: survey_ids).answered.group(:survey_id).count
    tagged_logger.info "Calculated submission counts by survey_id"

    last_impression_at_by_survey_id = submission_scope.where(survey_id: survey_ids).group(:survey_id).maximum(:created_at)
    tagged_logger.info "Calculated last impressions by survey_id"

    last_submission_at_by_survey_id = submission_scope.answered.where(survey_id: survey_ids).group(:survey_id).maximum(:created_at)
    tagged_logger.info "Calculated last submissions by survey_id"

    @num_created = 0
    @num_updated = 0
    @num_failed = 0

    impression_counts_by_survey_id.each do |survey_id, impression_count|
      submission_count = submission_counts_by_survey_id[survey_id].to_i
      viewed_impression_count = viewed_impression_counts_by_survey_id[survey_id].to_i
      last_submission_at = last_submission_at_by_survey_id[survey_id]
      last_impression_at = last_impression_at_by_survey_id[survey_id]

      create_or_update_cache(
        last_impression_at,
        last_submission_at,
        survey_id,
        submission_count,
        viewed_impression_count,
        impression_count,
        start_time,
        end_time
      )
    rescue StandardError => e
      tagged_logger.info "Failed to process survey: #{e}"
      @num_failed += 1
    end

    tagged_logger.info "Caching complete. Created #{@num_created} new records. Updated #{@num_updated} existing records. Failed to process #{@num_failed} surveys"

    return if @reported_double_counting

    tagged_logger.info "Backfilling started"

    @current_interval = start_time...end_time

    backfill_viewed_impressions
    backfill_submissions

    tagged_logger.info "Backfilling Finished"
  end

  private

  def create_or_update_cache(last_impression_at, last_submission_at, survey_id,
                             submission_count, viewed_impression_count,
                             impression_count, start_time, end_time)
    if cache_record = SurveySubmissionCache.find_by(survey_id: survey_id, applies_to_date: start_time.to_date)
      if !@reported_double_counting && !@run_by_admin && last_impression_at < cache_record.last_impression_at
        @reported_double_counting = true
        tagged_logger.info "Looks like we ran twice in the last 10 minutes :("
        Rollbar.error("Submission cache worker ran twice", start_time: start_time, end_time: end_time)
      end

      cache_record.increment(:submission_count, submission_count)
      cache_record.increment(:viewed_impression_count, viewed_impression_count)
      cache_record.increment(:impression_count, impression_count)
      cache_record.last_submission_at = last_submission_at unless last_submission_at.nil?
      cache_record.last_impression_at = last_impression_at
      cache_record.save

      @num_updated += 1 if cache_record.errors.none?
    else
      success = SurveySubmissionCache.create(
        survey_id: survey_id,
        applies_to_date: start_time.to_date,
        submission_count: submission_count,
        viewed_impression_count: viewed_impression_count,
        impression_count: impression_count,
        last_impression_at: last_impression_at,
        last_submission_at: last_submission_at
      )

      @num_created += 1 if success
    end
  end

  def backfill_viewed_impressions
    viewed_impressions_to_backfill = Submission.where.not(created_at: @current_interval).where(viewed_at: @current_interval)
    tagged_logger.info "#{viewed_impressions_to_backfill.count} viewed impressions to backfill"

    viewed_impressions_to_backfill.group(:survey_id, 'DATE(created_at)').count.each do |grouping_keys, viewed_impression_count|
      survey_id, applies_to_date = grouping_keys

      next unless cache = SurveySubmissionCache.find_by(survey_id: survey_id, applies_to_date: applies_to_date)

      cache.increment!(:viewed_impression_count, viewed_impression_count)
    end
  end

  def backfill_submissions
    submissions_to_backfill = Submission.where.not(created_at: @current_interval)
    submissions_to_backfill = submissions_to_backfill.joins(:answers).where(answers: { created_at: @current_interval }).where(<<~SQL)
      answers.id = (SELECT MIN(id) FROM answers WHERE submission_id = submissions.id)
    SQL
    tagged_logger.info "#{submissions_to_backfill.count} submissions to backfill"

    submissions_by_survey_and_date = submissions_to_backfill.group_by { |submission| [submission.survey_id, submission.created_at.to_date] }
    submissions_by_survey_and_date.each do |grouping_keys, submissions|
      survey_id, applies_to_date = grouping_keys

      next unless cache = SurveySubmissionCache.find_by(survey_id: survey_id, applies_to_date: applies_to_date)

      cache.increment!(:submission_count, submissions.count)

      last_submission_at = submissions.pluck(:created_at).max
      cache.update(last_submission_at: last_submission_at) if cache.last_submission_at.nil? || cache.last_submission_at < last_submission_at
    end
  end

  def floor_to_nearest_10th_minute(time)
    time.change(min: time.min.floor(-1), sec: 0)
  end
end
