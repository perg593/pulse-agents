# frozen_string_literal: true

require_relative "../../lib/ai_summarization"

class AISummarizationWorker
  include Sidekiq::Worker
  include Common

  def perform(ai_summarization_job_id)
    tagged_logger.info "Started"

    ai_summarization_job = AISummarizationJob.find_with_retry_by!(id: ai_summarization_job_id)

    unless ai_summarization_job.pending?
      tagged_logger.info "Record was not 'pending' (was '#{ai_summarization_job.status}') -- exiting"
      return
    end

    ai_summarization_job.update(status: :in_progress)

    answer_scope = ai_summarization_job.question.answers

    tagged_logger.info "Submitting #{answer_scope.count} answers for analysis"

    summary = AISummarization.summarize(answer_scope, strategy: AISummarization::STRATEGY_LAST_RESPONSES)

    tagged_logger.info "Done analyzing"

    ai_summarization_job.update(summary: summary, status: :done)
  rescue StandardError => e
    Rollbar.error e
    tagged_logger.error e
  ensure
    tagged_logger.info "Finished"
  end
end
