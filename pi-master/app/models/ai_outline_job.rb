# frozen_string_literal: true
class AIOutlineJob < ApplicationRecord
  audited

  enum status: [:pending, :generating_outline, :outline_completed, :generating_gamma, :completed, :failed]

  belongs_to :survey
  belongs_to :prompt_template, optional: true

  # Scopes
  scope :with_gamma_in_progress, -> { where(status: :generating_gamma) }
  scope :recently_created, -> { where('created_at > ?', 1.hour.ago) }

  validates :survey, presence: true

  def self.create_for_survey(survey, prompt_template: nil, prompt_text: nil, use_default_prompt: false, filters: {})
    create!(
      survey: survey,
      prompt_template: prompt_template,
      prompt_text: prompt_text,
      use_default_prompt: use_default_prompt,
      filters: filters,
      status: :pending
    )
  end

  def start_processing!
    update!(status: :generating_outline, started_at: Time.current)
  end

  def complete_outline!(outline_content)
    update!(
      status: :outline_completed,
      outline_content: outline_content,
      completed_at: Time.current
    )
  end

  def fail!(error_message = nil)
    update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
  end

  def processing?
    pending? || generating_outline? || outline_completed? || generating_gamma?
  end

  def job_completed?
    completed?
  end

  def job_finished?
    completed? || failed?
  end

  def outline_generation_completed?
    outline_completed? || generating_gamma? || completed?
  end

  def outline_generation_finished?
    outline_completed? || generating_gamma? || completed? || failed?
  end

  def errors?
    failed? && error_message.present?
  end

  def error_summary
    return nil unless errors?

    {
      status: status,
      error_message: error_message,
      failed_at: completed_at
    }
  end

  # Gamma presentation methods
  def start_gamma_generation!(generation_id)
    update!(
      gamma_generation_id: generation_id,
      status: :generating_gamma,
      gamma_started_at: Time.current
    )
  end

  def complete_gamma_generation!(gamma_url)
    update!(
      gamma_url: gamma_url,
      status: :completed,
      gamma_completed_at: Time.current
    )
  end

  def fail_gamma_generation!(error_message = nil)
    update!(
      status: :failed,
      gamma_completed_at: Time.current,
      error_message: error_message
    )
  end

  def gamma_processing?
    generating_gamma?
  end

  def gamma_ready?
    completed? && gamma_url.present?
  end

  def date_range
    return nil unless filters["date_range"]

    datetimes = filters["date_range"].split("..").map { |datetime_string| DateTime.parse(datetime_string) }
    datetimes.first..datetimes.last
  end

  def device_filter
    filters["device_filter"].present? ? Array.wrap(filters["device_filter"]) : nil
  end

  def market_ids
    filters["market_ids"].present? ? Array.wrap(filters["market_ids"]) : nil
  end

  def completion_url_filters
    filters["completion_urls"]&.map do |filter|
      filter.symbolize_keys!
      CompletionUrlFilter.new(filter[:matcher], filter[:value], cumulative: filter[:cumulative])
    end
  end

  def pageview_count_filter
    filter = filters["pageview_count"]&.symbolize_keys
    Filters::PageviewCountFilter.new(filter[:comparator], filter[:value]) if filter
  end

  def visit_count_filter
    filter = filters["visit_count"]&.symbolize_keys
    Filters::VisitCountFilter.new(filter[:comparator], filter[:value]) if filter
  end

  def submissions
    # Start with submissions that have answers
    submissions = survey.submissions.
                  joins(:answers).
                  where('submissions.answers_count > 0').
                  includes(:device, answers: [:question, :possible_answer, :tags])

    # Apply filters using Submission.filtered_submissions
    submissions = Submission.filtered_submissions(submissions, filters: normalized_filters)

    # Limit and order
    submissions.order(:created_at).limit(50)
  end

  private

  # Return a hash of all specified filters
  def normalized_filters
    normalized = {
      date_range: date_range,
      device_types: device_filter,
      completion_urls: completion_url_filters,
      market_ids: market_ids,
      pageview_count: pageview_count_filter,
      visit_count: visit_count_filter
    }

    normalized.delete_if { |_, value| !value.present? }

    normalized
  end
end

# == Schema Information
#
# Table name: ai_outline_jobs
#
#  id                  :bigint           not null, primary key
#  completed_at        :datetime
#  error_message       :text
#  filters             :jsonb
#  gamma_completed_at  :datetime
#  gamma_started_at    :datetime
#  gamma_url           :text
#  outline_content     :text
#  prompt_text         :text
#  started_at          :datetime
#  status              :integer          default("pending"), not null
#  use_default_prompt  :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  gamma_generation_id :string
#  prompt_template_id  :bigint
#  survey_id           :bigint           not null
#
# Indexes
#
#  index_ai_outline_jobs_on_gamma_generation_id       (gamma_generation_id)
#  index_ai_outline_jobs_on_prompt_template_id        (prompt_template_id)
#  index_ai_outline_jobs_on_status                    (status)
#  index_ai_outline_jobs_on_survey_id                 (survey_id)
#  index_ai_outline_jobs_on_survey_id_and_created_at  (survey_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (prompt_template_id => prompt_templates.id)
#  fk_rails_...  (survey_id => surveys.id)
#
