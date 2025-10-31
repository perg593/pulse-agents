# frozen_string_literal: true

class WorkerOutputSummaryMailer < ActionMailer::Base
  default cc: ["dev.pulseinsights@ekohe.com", "ops@pulseinsights.com"]

  def output_urls(worker_output_copies, start_date, end_date)
    @worker_output_copies = worker_output_copies
    @activity_date = activity_date(start_date, end_date)
    mail(to: 'monitoring@pulseinsights.com', subject: 'Pulse Insights Daily Worker Output URLs')
  end

  private

  def activity_date(start_date, end_date)
    start_date == end_date ? "on #{start_date}" : "from #{start_date} to #{end_date}"
  end
end
