# frozen_string_literal: true

class WorkerOutputSummaryWorker
  include Sidekiq::Worker
  include Common

  def perform(start_time: nil, end_time: nil)
    tagged_logger.info 'Started'

    start_time ||= Time.now.utc.yesterday.beginning_of_day
    end_time ||= Time.now.utc.yesterday.end_of_day
    tagged_logger.info "Time Range: #{start_time}..#{end_time}"

    worker_output_copies = WorkerOutputCopy.where(updated_at: start_time..end_time).order(:worker_name, :updated_at)
    tagged_logger.info "Output: #{worker_output_copies.pluck(:id, :file_name, :signed_url)}"

    WorkerOutputSummaryMailer.output_urls(worker_output_copies, start_time.to_date, end_time.to_date).deliver_now
    tagged_logger.info 'Delivered Email'
  rescue => e
    tagged_logger.error e
    Rollbar.error e, start_time: start_time, end_time: end_time, output_copies: worker_output_copies
  ensure
    tagged_logger.info 'Finished'
  end
end
