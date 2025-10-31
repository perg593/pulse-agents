# frozen_string_literal: true
class FreeTextAnalyzer
  include Sidekiq::Worker

  def perform(survey_id)
    return if Rails.env.development? || Rails.env.test?

    survey = Survey.find(survey_id)
    survey.free_text_analyze!
  rescue ActiveRecord::RecordNotFound => e
    # Do nothing, the survey just got deleted since this job has been created
    return
  end
end
