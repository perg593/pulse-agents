# frozen_string_literal: true

module SurveyOverviewDocuments
  class CaptureScreenshotsWorker
    include Sidekiq::Worker
    include Common

    def perform(survey_overview_document_id)
      tagged_logger.info "Started"

      survey_overview_document = SurveyOverviewDocument.find(survey_overview_document_id)

      unless survey_overview_document.capturing_remote_screenshots?
        tagged_logger.info "Record was not 'capturing_remote_screenshots' (was '#{survey_overview_document.status}') -- exiting"
        return
      end

      survey_overview_document.take_screenshots_of_client_page

      # Queue presentation generation after successful screenshot capture
      GeneratePresentationWorker.perform_async(survey_overview_document_id)
    rescue StandardError => e
      # Don't fail the document - keep it in capturing_remote_screenshots state with error
      # This allows users to retry with corrected configuration
      survey_overview_document&.update!(failure_reason: "Failed to capture screenshots: #{e.message}")

      Rollbar.error e
      tagged_logger.error e
    ensure
      tagged_logger.info "Finished"
    end
  end
end
