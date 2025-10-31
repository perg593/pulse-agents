# frozen_string_literal: true
module Control
  class SurveyLocaleGroupsController < BaseController
    before_action :require_full_access_user!

    def create
      survey = current_user.account.surveys.find_by(id: params[:survey_id])
      unless survey
        redirect_to dashboard_path
        return
      end

      survey_locale_group_name = params[:survey_locale_group].try(:[], :name)
      unless survey_locale_group_name.present?
        flash.alert = "Error: Missing name for group"
        redirect_to dashboard_path
        return
      end

      survey.localize!(group_name: survey_locale_group_name)
      survey.reload

      if survey.localized?
        redirect_to localization_editor_path(survey.survey_locale_group_id)
      else
        flash.alert = "Failed to localize survey, please contact system admin"
        redirect_to dashboard_path
      end
    end

    def inline_edit
      survey_locale_group = current_user.account&.survey_locale_groups&.find_by(id: params[:id])
      render json: :forbidden, status: 404 and return unless survey_locale_group

      survey_locale_group.update(name: params[:survey_locale_group][:name])

      if survey_locale_group.errors.empty?
        render json: {}, status: :ok
      else
        render json: {}, status: :bad_request
      end
    end
  end
end
