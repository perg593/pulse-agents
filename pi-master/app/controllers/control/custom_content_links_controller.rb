# frozen_string_literal: true
module Control
  class CustomContentLinksController < BaseController
    before_action :require_full_access_user!, :set_custom_content_link

    def update_color
      render json: { error: 'Not Found' }, status: 404 and return unless @custom_content_link
      render json: { error: 'Color Blank' }, status: 400 and return if params[:color].blank?
      render json: { error: "Invalid Color" }, status: 400 and return unless @custom_content_link.update(report_color: params[:color])
      render json: :ok
    end

    private

    def set_custom_content_link
      return unless custom_content_question = Question.where(survey: current_account.surveys).find_by(id: params['question_id'])

      @custom_content_link = custom_content_question.custom_content_links.find_by(id: params['id'])
    end
  end
end
