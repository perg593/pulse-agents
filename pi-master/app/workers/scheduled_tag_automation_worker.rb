# frozen_string_literal: true

class ScheduledTagAutomationWorker
  include Sidekiq::Worker
  include Common

  def perform
    tagged_logger.info 'Started'

    questions = Question.select(&:due_for_tag_automation?)
    tagged_logger.info "Question IDs: #{questions.pluck(:id)}"

    questions.each do |question|
      tag_automation_job = question.tag_automation_jobs.create(answers: question.answers.auto_tag_eligible)
      TagAutomationWorker.perform_in(1.second, tag_automation_job.id) # 1 sec delay is a workaround for replication lag
    end
  rescue => e
    Rollbar.error e
    tagged_logger.error "Error: #{e.full_message}"
  ensure
    tagged_logger.info 'Finished'
  end
end
