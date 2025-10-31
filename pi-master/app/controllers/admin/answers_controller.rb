# frozen_string_literal: true
module Admin
  class AnswersController < BaseController
    def index
      @start_date = params[:date_from].presence || 1.week.ago
      @end_date = params[:date_to]

      respond_to do |format|
        format.html
        format.json { render json: AnswersDatatable.new(view_context, @start_date, @end_date) }
      end
    end
  end
end
