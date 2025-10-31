# frozen_string_literal: true

class TagAutomationWorker
  include Sidekiq::Worker
  include Common

  def perform(tag_automation_job_id)
    tagged_logger.info 'Started'

    tag_automation_job = TagAutomationJob.find_by(id: tag_automation_job_id)
    tagged_logger.error "TagAutomationJob not found: #{tag_automation_job_id}" and return unless tag_automation_job

    tag_automation_job.auto_tag
    tag_automation_job.completed!
  rescue => e
    Rollbar.error e
    tagged_logger.error "Error: #{e.full_message}"
  ensure
    tag_automation_job&.failed! unless tag_automation_job&.completed?
    tagged_logger.info 'Finished'
  end
end
