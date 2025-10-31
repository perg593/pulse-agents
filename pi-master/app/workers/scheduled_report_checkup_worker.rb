# frozen_string_literal: true
class ScheduledReportCheckupWorker
  include Sidekiq::Worker

  def perform
    stalled_reports = ScheduledReport.stalled
    skipped_reports, failed_reports = ScheduledReport.failed.partition(&:skip?)

    return unless stalled_reports.present? || failed_reports.present? || skipped_reports.present?

    ScheduledReportCheckupMailer.checkup_report(stalled_reports, failed_reports, skipped_reports).deliver_now
  end
end
