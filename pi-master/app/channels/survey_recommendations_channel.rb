# frozen_string_literal: true

class SurveyRecommendationsChannel < ApplicationCable::Channel
  def subscribed
    survey_id = params[:survey_id]

    reject and return unless survey_id.present?

    reject and return unless current_user.surveys.find_by(id: survey_id)

    stream_from "survey_recommendations_#{survey_id}"
  end
end
