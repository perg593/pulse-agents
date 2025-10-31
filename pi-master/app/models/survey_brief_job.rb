# frozen_string_literal: true

class SurveyBriefJob < ActiveRecord::Base
  audited

  enum status: [:pending, :in_progress, :done, :failed]

  belongs_to :survey

  scope :unfinished, -> { where(status: [:pending, :in_progress]) }

  validate :no_unfinished_jobs, if: ->(survey_brief_job) { !survey_brief_job.done? }
  validate :no_duplicate_requests, if: ->(survey_brief_job) { survey_brief_job.done? }

  def no_unfinished_jobs
    return unless self.class.unfinished.where(survey_id: survey_id).where.not(id: id).exists?

    errors.add(:status, "An analysis is already in progress. Please stand by.")
  end

  def no_duplicate_requests
    return unless self.class.done.where(survey_id: survey_id, input: input).where.not(id: id).exists?

    errors.add(:input, "This survey has already been analyzed.")
  end
end

# == Schema Information
#
# Table name: survey_brief_jobs
#
#  id         :bigint           not null, primary key
#  brief      :text
#  input      :text
#  status     :integer          default("pending")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  survey_id  :bigint
#
# Indexes
#
#  index_survey_brief_jobs_on_survey_id  (survey_id)
#
