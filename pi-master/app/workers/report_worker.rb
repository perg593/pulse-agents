# frozen_string_literal: true
# In this worker we take a ReportJob and generate the xlsx file.
# We store in /tmp directory then upload it to S3 ('pi-reports' bucket)
# We update ReportJob object with the public URL then delete the file in /tmp
# We also send an email to the user with the URL

class ReportWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common
  include Report
  include Control::SurveysHelper
  include Control::DatesHelper

  def perform(report_job_id)
    tagged_logger.tagged report_job_id do
      tagged_logger.info "Processing Report"

      @report_job = ReportJob.find(report_job_id)

      tagged_logger.info @report_job.inspect

      if @report_job.in_progress?
        tagged_logger.info "Report already in progress -- exiting"
        return
      end

      set_variables

      report_job_in_progress!

      tagged_logger.info "Generating XLSX report"
      package = generate_xlsx(date_format: "%m/%d/%y")
      @axlsx_package = package

      unless package.serialize(xlsx_filepath, confirm_valid: true)
        report_to_rollbar("ReportWorkerError: invalid XLSX", report_job_id: report_job_id,
                          file_path: xlsx_filepath, error_messages: package.validate.map(&:message))
      end

      tagged_logger.info "Uploading report"
      @file_url = upload_xlsx_file
      report_job_save_url!

      tagged_logger.info "Sending e-mail"
      send_email

      tagged_logger.info "Cleaning up"
      File.delete(xlsx_filepath)
      report_job_as_done!

      tagged_logger.info "Done processing Report"
    end

    @axlsx_package
  rescue StandardError => e
    report_to_rollbar("ReportWorker Error: #{e.inspect}", report_job_id: report_job_id, file_url: @file_url, error_message: e.full_message)
  end

  private

  def send_email
    case @reportee
    when SurveyLocaleGroup
      ReportMailer.localization_report(email_params, current_user_email: @current_user_email, sudo_from_id: @sudo_from_id).deliver_now
    when Survey
      ReportMailer.send_report(email_params, current_user_email: @current_user_email, sudo_from_id: @sudo_from_id).deliver_now
    end
  end

  def email_params
    super.merge(
      reportee: @reportee,
      individual_rows_report_path: individual_rows_filepath,
      attach_csv_file: attach_csv_file_to_email?,
      report_csv_url: @report_csv_urls[localized_report? ? :locale_groups : :surveys].values.first
    )
  end

  # TODO: Simplify
  def set_variables
    @reportee = @report_job.survey_locale_group
    @reportee ||= @report_job.survey

    @today = Time.current
    @date_range = @report_job.date_range

    @filters = {
      device_types: @report_job.device_filter,
      completion_urls: @report_job.completion_url_filters,
      market_ids: @report_job.market_ids,
      pageview_count: @report_job.pageview_count_filter,
      visit_count: @report_job.visit_count_filter,
      date_range: @date_range
    }.compact

    @sudo_from_id = @report_job.sudo_from_id
    @current_user_email = @report_job.current_user_email

    @account = @reportee.account
    @include_ip_column = !@account.store_none?

    compute_survey_stats

    @report_csv_urls = { locale_groups: {}, surveys: {} }
  end

  def xlsx_filename
    "Pulse Insights #{'Localization ' if localized_report?}Report #{@reportee.name.parameterize} #{@today.strftime("%F %s")}.xlsx"
  end
end
