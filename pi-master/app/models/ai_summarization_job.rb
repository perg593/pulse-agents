# frozen_string_literal: true

class AISummarizationJob < ApplicationRecord
  audited

  enum status: [:pending, :in_progress, :done]

  belongs_to :question

  scope :unfinished, -> { where(status: [:pending, :in_progress]) }

  validate :appropriate_question
  validate :no_unfinished_summarization_jobs, if: ->(ai_summarization_job) { !ai_summarization_job.done? }

  private

  def appropriate_question
    return if question.free_text_question?

    errors.add(:question, "Only free text questions can be analyzed.")
  end

  def no_unfinished_summarization_jobs
    return unless self.class.unfinished.where(question_id: question_id).where.not(id: id).exists?

    errors.add(:status, "An analysis is already in progress. Please stand by.")
  end
end

# == Schema Information
#
# Table name: ai_summarization_jobs
#
#  id          :bigint           not null, primary key
#  status      :integer          default("pending")
#  summary     :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  question_id :bigint
#
# Indexes
#
#  index_ai_summarization_jobs_on_question_id  (question_id)
#  index_ai_summarization_jobs_on_status       (status) WHERE (status = ANY (ARRAY[0, 1]))
#
