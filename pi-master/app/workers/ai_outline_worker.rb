# frozen_string_literal: true
require_relative '../lib/ai_outline_generation'

class AIOutlineWorker
  include Sidekiq::Worker

  def perform(job_id)
    job = AIOutlineJob.find(job_id)

    # Don't process if outline generation is already finished
    return if job.outline_generation_finished?

    job.start_processing!

    begin
      # Real AI outline generation
      outline_content = AIOutlineGeneration.generate_outline(job)

      job.complete_outline!(outline_content)
    rescue => e
      job.fail!(e.message)
      raise e
    end
  end
end
