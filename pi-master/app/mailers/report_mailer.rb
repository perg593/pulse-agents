# frozen_string_literal: true

class ReportMailer < ActionMailer::Base
  def send_report(data, current_user_email: nil, sudo_from_id: nil)
    set_variables(data.merge(current_user_email: current_user_email, sudo_from_id: sudo_from_id))
    from_to_with_timezone

    @scheduled_report_emails = data[:emails]

    attach_file
    mail(to: emails, bcc: bcc_addresses, subject: "[Pulse Insights] Report - #{@report_name}")
  end

  def localization_report(data, current_user_email: nil, sudo_from_id: nil)
    set_variables(data.merge(current_user_email: current_user_email, sudo_from_id: sudo_from_id))
    from_to_with_timezone

    @scheduled_report_emails = data[:emails]

    attach_file
    mail(to: emails, bcc: bcc_addresses, subject: "[Pulse Insights] Localization Report - #{@report_name}")
  end

  def benjamin_moore_notification(report_url, qc_url)
    @report_url = report_url
    @qc_url = qc_url

    mail(to: "jdippold@pulseinsights.com", bcc: bcc_addresses, subject: "Benjamin Moore report links")
  end

  private

  # rubocop:disable Naming/AccessorMethodName
  # not really in the scope of this offence
  def set_variables(data)
    %w(account reportee reportee_survey_ids report_name report_path report_url current_user_email sudo_from_id
       attach_file date_range from to scheduled_report_id submissions_count impressions_count submission_rate
       questions individual_rows_report_path report_csv_url attach_csv_file).each do |attr|
      instance_variable_set("@#{attr}", data[attr.to_sym]) if data[attr.to_sym]
    end
  end

  # rubocop:disable  Style/ParallelAssignment
  # these vars are closely related and there's only 2, so an incentive is not strong to break it into a few lines
  def from_to_with_timezone
    @from, @to = Time.zone.at(@date_range.first), Time.zone.at(@date_range.last) if @date_range
  end

  def attach_file
    attachments.inline[@report_name] = File.read("#{Rails.root}/#{@report_path}") if @attach_file
    attachments.inline["individual_rows.csv"] = File.read("#{Rails.root}/#{@individual_rows_report_path}") if @individual_rows_report_path && @attach_csv_file
  end

  def emails
    if @scheduled_report_emails&.any?
      @scheduled_report_emails
    elsif @sudo_from_id # used 'Log In As', should not send email to survey owner
      ['alerts@pulseinsights.com']
    else
      [@current_user_email]
    end
  end

  def bcc_addresses
    return if emails.include? 'staging.scan@rapid7.com' # Cobalt pen test

    %w(alerts@pulseinsights.com ops@pulseinsights.com)
  end
end
