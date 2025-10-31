# frozen_string_literal: true
class ScheduledReportWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform
    tagged_logger.info "Processing ScheduledReports"

    scheduled_reports = ScheduledReport.due_for_processing.where(in_progress: false)

    num_reports = scheduled_reports.count
    tagged_logger.info "Found #{num_reports} reports to process"

    num_skipped = 0

    scheduled_reports.each do |scheduled_report|
      tagged_logger.tagged "#{scheduled_report.name} (#{scheduled_report.id})" do
        tagged_logger.info "Considering report"

        if skip_report?(scheduled_report)
          num_skipped += 1
          next
        end

        scheduled_report.update(in_progress: true)

        tagged_logger.info "report in_progress? #{scheduled_report.in_progress}"
        IndividualScheduledReportWorker.perform_in(10.seconds.from_now, scheduled_report.id)

        tagged_logger.info "Done processing report"
      end
    end

    tagged_logger.info "Finished queuing reports: #{num_reports - num_skipped} queued, #{num_skipped} skipped"
  end

  private

  def skip_report?(scheduled_report)
    return false unless scheduled_report.skip?

    scheduled_report.skip_reasons.each do |skip_reason, explanation|
      tagged_logger.info "#{explanation} -- skipping"
      report_to_rollbar "Attempted to queue Scheduled Report twice in one day", scheduled_report_id: scheduled_report.id if skip_reason == :ran_recently
    end

    true
  end
end
