# frozen_string_literal: true

class CleanupSubmissionsMailer < ActionMailer::Base
  def daily_report_email(emails, data)
    @data = data
    mail(to: emails, subject: '[Pulse Insights] daily impressions deletion')
  end
end
