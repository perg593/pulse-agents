# frozen_string_literal: true

module SurveyOverviewDocuments
  class GeneratePresentationWorker
    include Sidekiq::Worker
    include Common

    def perform(survey_overview_document_id)
      tagged_logger.info "Started"

      survey_overview_document = SurveyOverviewDocument.find(survey_overview_document_id)

      unless survey_overview_document.generating_slides?
        tagged_logger.info "Record was not 'generating_slides' (was '#{survey_overview_document.status}') -- exiting"
        return
      end

      survey_overview_document.generate_presentation
    rescue StandardError => e
      survey_overview_document&.fail!("Failed to generate presentation: #{e.message}")

      Rollbar.error e
      tagged_logger.error e
    ensure
      tagged_logger.info "Finished"
    end
  end
end
