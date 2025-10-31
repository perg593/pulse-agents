# frozen_string_literal: true

class CompleteExpiredSurveysWorker
  include Sidekiq::Worker
  include Common

  def perform
    tagged_logger.info "Started"

    expired_surveys = Survey.live.where.not(ends_at: nil).where("ends_at <= ?", Time.current)

    tagged_logger.info "Found #{expired_surveys.count} expired surveys to complete"

    completed_count = 0

    expired_surveys.find_each do |survey|
      tagged_logger.tagged("Survey ID: #{survey.id}") do
        survey.update!(status: :complete)
        SurveyMailer.survey_reached_end_date_email(survey.id).deliver_now

        completed_count += 1
        tagged_logger.info "Marked survey '#{survey.name}' as complete"
      rescue => e
        tagged_logger.error "Failed to complete survey #{survey.id}: #{e.message}"
        Rollbar.error(e, "Failed to complete survey", survey_id: survey.id, survey_name: survey.name)
      end
    end

    tagged_logger.info "Completed #{completed_count} surveys"
  rescue => e
    tagged_logger.error "Error: #{e.full_message}"
    Rollbar.error(e)
  ensure
    tagged_logger.info "Finished"
  end
end
