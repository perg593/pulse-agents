# frozen_string_literal: true

module Control
  class AISummarizationJobsController < BaseController
    before_action :set_ai_summarization_job, only: [:show]

    include RedirectHelper

    # GET /ai_summarization_jobs/1
    def show
      job_account = @ai_summarization_job.question.survey.account
      render json: { error: "Unauthorized. Wrong account." }, status: :forbidden and return unless job_account == current_user.account

      response_object = {
        datetime: @ai_summarization_job.created_at.strftime("%m/%d/%Y %H:%M"),
        summary: @ai_summarization_job.summary,
        status: @ai_summarization_job.status
      }

      render json: response_object, status: :ok and return
    end

    # POST /ai_summarization_jobs
    def create
      render json: { error: "Feature disabled for this account." }, status: :forbidden and return unless current_user.account.ai_summaries_enabled

      question = Question.where(id: params[:ai_summarization_job][:question_id]).first
      render json: { error: "Unauthorized" }, status: :not_found and return if question.nil? || question.survey.account != current_user.account

      @ai_summarization_job = AISummarizationJob.new(ai_summarization_job_params)

      if @ai_summarization_job.save
        AISummarizationWorker.perform_async(@ai_summarization_job.id)
        render json: { id: @ai_summarization_job.id }, status: :ok
      else
        render json: { error: @ai_summarization_job.errors.full_messages.join(',') }, status: 500
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_ai_summarization_job
      @ai_summarization_job = AISummarizationJob.find_by(id: params[:id])

      handle_missing_record unless @ai_summarization_job
    end

    def ai_summarization_job_params
      params.require(:ai_summarization_job).permit(:question_id)
    end
  end
end
