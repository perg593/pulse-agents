# frozen_string_literal: true
class ScheduledReportMailer < ActionMailer::Base
  def send_report(report_xlsx_urls, emails, report_name, report_id, date, report_csv_urls, report_result_counts, human_date_range)
    @emails = emails
    @report_xlsx_urls = report_xlsx_urls
    @report_csv_urls = report_csv_urls
    @report = ScheduledReport.find_by id: report_id
    @account = @report.account
    @report_result_counts = report_result_counts
    @human_date_range = human_date_range

    mail(to: @emails, subject: "Pulse Insights Scheduled Export: #{report_name} for #{date}")
  end

  def no_results(emails, report_name, report_id, date, human_date_range)
    @emails = emails
    @report = ScheduledReport.find_by id: report_id
    @human_date_range = human_date_range
    @account = @report.account

    mail(to: @emails, subject: "Pulse Insights Scheduled Export: #{report_name} for #{date}")
  end
end
