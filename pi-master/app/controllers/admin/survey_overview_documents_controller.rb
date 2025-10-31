# frozen_string_literal: true

module Admin
  class SurveyOverviewDocumentsController < BaseController
    before_action :set_survey_overview_document, only: [:presentation_url, :capture_screenshots, :show, :update]
    before_action :check_same_account

    def create
      @survey_overview_document = SurveyOverviewDocument.new(survey_overview_document_params)

      if @survey_overview_document.save
        render json: @survey_overview_document.as_json(only: [:id, :status]), status: :created
      else
        render json: { errors: @survey_overview_document.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @survey_overview_document.update(survey_overview_document_params)
        render json: @survey_overview_document.as_json(only: [:id, :status]), status: :ok
      else
        render json: { errors: @survey_overview_document.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
      render json: {
        status: @survey_overview_document.status,
        google_presentation_url: @survey_overview_document.google_presentation_url,
        failure_reason: @survey_overview_document.failure_reason
      }
    end

    def presentation_url
      if url = @survey_overview_document.google_presentation_url
        render json: { url: url }
      else
        render json: { error: 'The presentation is not ready yet. Please contact support for assistance.' }, status: :not_found
      end
    end

    def capture_screenshots
      # Clear any previous failure reason when starting a new capture
      @survey_overview_document.update!(failure_reason: nil)

      # Start the process in the background
      SurveyOverviewDocuments::CaptureScreenshotsWorker.perform_async(@survey_overview_document.id)
      render json: { status: @survey_overview_document.status }
    end

    private

    def set_survey_overview_document
      @survey_overview_document = SurveyOverviewDocument.find(params[:id])
    end

    def check_same_account
      survey = if action_name == "create"
        Survey.find_by_id(survey_overview_document_params[:survey_id])
      else
        @survey_overview_document&.survey
      end

      if current_account.surveys.include?(survey)
        true
      else
        render json: { error: 'You do not have permission to access this survey. Please contact support for assistance.' }, status: 403
        false
      end
    end

    def survey_overview_document_params
      params.require(:survey_overview_document).permit(
        :survey_editor_screenshot,
        :survey_id,
        client_site_configuration: [
          :target_url,
          { cookie_selectors: [] },
          { viewport_config: [:desktop_width, :desktop_height, :mobile_width, :mobile_height] },
          {
            authentication_config: [
              :type,
              :username,
              :password,
              {
                form_selectors: [
                  :username_selector,
                  :password_selector,
                  :submit_selector
                ]
              }
            ]
          }
        ]
      )
    end
  end
end
