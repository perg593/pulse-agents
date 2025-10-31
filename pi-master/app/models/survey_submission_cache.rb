# frozen_string_literal: true
class SurveySubmissionCache < ActiveRecord::Base
  belongs_to :survey

  def self.remove_submission_record(submission_record)
    cache_record = where(survey_id: submission_record.survey_id, applies_to_date: submission_record.created_at.to_date).first

    return unless cache_record

    # This is much faster than recalculating cache_record counts
    cache_record.impression_count -= 1
    cache_record.viewed_impression_count -= 1 if submission_record.viewed_at.present?
    cache_record.submission_count -= 1 if submission_record.answers_count.positive?

    if cache_record.impression_count.zero?
      cache_record.destroy
      return
    end

    time_range = submission_record.created_at.beginning_of_day..submission_record.created_at.end_of_day
    impression_scope = Submission.where(survey_id: submission_record.survey_id, created_at: time_range)

    unless submission_record.created_at < cache_record.last_impression_at
      cache_record.last_impression_at = impression_scope.order(:created_at).last.created_at
    end

    unless submission_record.created_at < cache_record.last_submission_at
      cache_record.last_submission_at = impression_scope.answered.order(:created_at).last&.created_at
    end

    cache_record.save
  end

  def self.recalculate(survey_id, date)
    impression_scope = Submission.where(survey_id: survey_id, created_at: date.beginning_of_day..date.end_of_day)

    record = where(survey_id: survey_id, applies_to_date: date).first

    if impression_scope.count.zero?
      record&.destroy
      return
    end

    unless record.present?
      record = create(survey_id: survey_id, applies_to_date: date)
    end

    record.impression_count = impression_scope.count
    record.viewed_impression_count = impression_scope.viewed.count
    record.submission_count = impression_scope.answered.count

    record.last_impression_at = impression_scope.order(:created_at).last.created_at
    record.last_submission_at = impression_scope.answered.order(:created_at).last&.created_at

    record.save
    record
  end
end

# == Schema Information
#
# Table name: survey_submission_caches
#
#  id                      :bigint           not null, primary key
#  applies_to_date         :date             not null
#  impression_count        :integer          default(0), not null
#  last_impression_at      :datetime
#  last_submission_at      :timestamptz
#  submission_count        :integer          default(0), not null
#  viewed_impression_count :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  survey_id               :bigint
#
# Indexes
#
#  index_survey_submission_caches_on_survey_id                      (survey_id)
#  index_survey_submission_caches_on_survey_id_and_applies_to_date  (survey_id,applies_to_date) UNIQUE
#
