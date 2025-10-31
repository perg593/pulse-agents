# frozen_string_literal: true

module Control
  class SurveyRecommendationsController < BaseController
    include FiltersHelper

    before_action :set_survey
    before_action :require_full_access_user!, only: :create

    def index
      render json: @survey.recommendations.recent.as_json(only: %i(id content filters created_at))
    end

    def create
      SurveyRecommendationWorker.perform_async(@survey.id, filter_params.to_hash)
    end

    private

    def set_survey
      handle_missing_record unless @survey = current_account.surveys.find_by(id: params[:survey_id])
    end

    def filter_params
      params.permit(
        :date_range, :from, :to,
        :possible_answer_id,
        :pageview_count,
        :visit_count,
        device_types: [],
        completion_urls: []
      )
    end
  end
end
