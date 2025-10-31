# frozen_string_literal: true

class WorkerOutputSummaryMailerPreview < ActionMailer::Preview
  def output_urls
    5.times do
      worker_name = "#{FFaker::Lorem.word.underscore}_worker"
      file_name = "#{worker_name}.#{%w(csv json xlsx).sample}"
      signed_url = "https://s3-bucket/#{SecureRandom.hex}#{file_name}"
      WorkerOutputCopy.create(worker_name: worker_name, file_name: file_name, signed_url: signed_url)
    end

    current_time = Time.current
    time_range = current_time.beginning_of_day..current_time.end_of_day
    worker_output_urls = WorkerOutputCopy.where(updated_at: time_range)
    WorkerOutputSummaryMailer.output_urls(worker_output_urls, time_range.first.to_date, time_range.last.to_date)
  end
end
