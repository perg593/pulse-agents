# frozen_string_literal: true
class ScheduledReportCheckupMailer < ActionMailer::Base
  def checkup_report(stalled_reports, failed_reports, skipped_reports)
    @stalled_reports = stalled_reports
    @failed_reports = failed_reports
    @skipped_reports = skipped_reports

    mail(to: "dev.pulseinsights@ekohe.com", cc: "ops@pulseinsights.com", subject: "Scheduled report failures")
  end
end
