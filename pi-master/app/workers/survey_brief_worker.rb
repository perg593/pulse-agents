# frozen_string_literal: true

class SurveyBriefWorker
  include Sidekiq::Worker
  include Common

  def perform(survey_brief_job_id)
    tagged_logger.info "Started"

    survey_brief_job = SurveyBriefJob.find(survey_brief_job_id)

    unless survey_brief_job.pending?
      tagged_logger.info "Record was not 'pending' (was '#{survey_brief_job.status}') -- exiting"
      return
    end

    survey_brief_job.update(status: :in_progress)

    brief_generator = SurveyBriefGenerator.new(survey_brief_job.survey)
    brief = brief_generator.generate
    input = brief_generator.prompt

    survey_brief_job.update(status: :done, brief: brief, input: input)
  rescue StandardError => e
    survey_brief_job&.update(status: :failed)

    Rollbar.error e
    tagged_logger.error e
  ensure
    tagged_logger.info "Finished"
  end
end
