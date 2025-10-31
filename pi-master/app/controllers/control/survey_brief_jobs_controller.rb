# frozen_string_literal: true
module Control
  class SurveyBriefJobsController < BaseController
    before_action :set_survey_brief_job, only: [:show]
    before_action :check_full_access, only: [:create]
    before_action :check_same_account, only: [:create]
    before_action :check_feature_enabled, only: [:create]

    include RedirectHelper

    def show
      render json: @survey_brief_job.as_json(only: [:status, :brief])
    end

    def create
      @survey_brief_job = SurveyBriefJob.new(survey_brief_job_params)

      if @survey_brief_job.save
        SurveyBriefWorker.perform_async(@survey_brief_job.id)

        render json: @survey_brief_job.as_json(only: [:id])
      else
        render json: @survey_brief_job.errors, status: :unprocessable_entity
      end
    end

    private

    def check_same_account
      if current_account.surveys.find_by_id(survey_brief_job_params[:survey_id])
        true
      else
        render json: :forbidden, status: 403
        false
      end
    end

    def check_full_access
      if current_user.full?
        true
      else
        render json: :forbidden, status: 403
        false
      end
    end

    def set_survey_brief_job
      @survey_brief_job = SurveyBriefJob.joins(survey: :account).find_by(id: params[:id], survey: { account: current_account })

      handle_missing_record unless @survey_brief_job
    end

    def survey_brief_job_params
      params.require(:survey_brief_job).permit(:survey_id)
    end

    def check_feature_enabled
      render json: :forbidden, status: 403 unless current_account.survey_brief_agent_enabled?
    end
  end
end
