# frozen_string_literal: true

# rubocop:disable Naming/AccessorMethodName
class IndividualScheduledReportWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common
  include Report
  include Control::SurveysHelper
  include ActionView::Helpers::NumberHelper

  # rubocop:disable Metrics/AbcSize
  # We have a lot of things to track
  # rubocop:disable Metrics/MethodLength, Metrics/BlockLength
  # Trying to understand failure to change in_progress to false
  def perform(scheduled_report_id)
    @scheduled_report = ScheduledReport.find(scheduled_report_id)
    @filepaths = []
    @num_surveys_examined = 0
    @scheduled_report.update(last_attempt_at: Time.current)

    tagged_logger.tagged "#{@scheduled_report.name} (#{scheduled_report_id})" do
      tagged_logger.info "Processing ScheduledReport"
      tagged_logger.info "report in_progress? beginning: #{@scheduled_report.in_progress}"

      @axlsx_packages = []

      @include_ip_column = !@scheduled_report.account.store_none?

      @emails = @scheduled_report.scheduled_report_emails.pluck(:email)
      @report_csv_urls = { locale_groups: {}, surveys: {} }
      @report_result_counts = { locale_groups: {}, surveys: {} }
      report_xlsx_urls = fetch_report_xlsx_urls

      tagged_logger.info "Compiled survey report URLs: #{report_xlsx_urls}"

      report_count = report_count(report_xlsx_urls)
      report_date = Time.current.to_date.strftime(DATE_FORMAT)

      if report_count.zero? && !@scheduled_report.send_no_results_email?
        tagged_logger.info "No results found -- skipping e-mail delivery"
      elsif report_count.zero?
        tagged_logger.info "Delivering no results report"
        ScheduledReportMailer.no_results(@emails, @scheduled_report.name, scheduled_report_id, report_date, human_date_range).deliver_now
      elsif report_count == 1 && @num_surveys_examined == 1
        tagged_logger.info "Delivering single report"
        send_single_report_email
      else
        tagged_logger.info "Delivering multiple reports"

        ScheduledReportMailer.send_report(
          report_xlsx_urls, @emails, @scheduled_report.name, scheduled_report_id, report_date, @report_csv_urls, @report_result_counts, human_date_range
        ).deliver_now
      end

      clean_up_files # deleting _after_ delivery because file might be attached to e-mail

      @scheduled_report.update_send_next_report_at
      tagged_logger.info "Next report will be delivered at #{@scheduled_report.send_next_report_at}"

      tagged_logger.info "report in_progress? before: #{@scheduled_report.in_progress}"
      @scheduled_report.update!(in_progress: false)
      tagged_logger.info "report in_progress? after: #{@scheduled_report.in_progress}"

      @axlsx_packages
    rescue StandardError => e
      tagged_logger.error e
      Rollbar.error(e, "Scheduled Report failure", scheduled_report_id: scheduled_report_id)

      false
    end
  end

  # Delete all generated xlsx files
  def clean_up_files
    @filepaths.each do |filepath|
      File.delete(filepath)
    rescue Errno::ENOENT => e
      Rollbar.error(e, scheduled_report_id: @scheduled_report.id)
    end
  end

  # override
  # public for testing purposes
  def individual_rows_filepath
    "tmp/pulse_insights_scheduled_report_individual_rows_#{@scheduled_report.name.gsub('/', ' ')} - #{@reportee.name.gsub('/', ' ')} #{@today}.csv"
  end

  private

  def send_single_report_email
    case @reportee
    when SurveyLocaleGroup
      ReportMailer.localization_report(email_params).deliver_now
    when Survey
      ReportMailer.send_report(email_params).deliver_now
    end
  end

  def report_count(report_xlsx_urls)
    (report_xlsx_urls[:locale_groups].values + report_xlsx_urls[:surveys].values).compact.count
  end

  def fetch_report_xlsx_urls
    report_xlsx_urls = { locale_groups: {}, surveys: {} }

    if @scheduled_report.all_surveys
      survey_locale_groups = @scheduled_report.account.survey_locale_groups
      survey_locale_groups.order(:created_at).each do |survey_locale_group|
        report_xlsx_urls[:locale_groups][survey_locale_group.id] = create_report(survey_locale_group)
        @report_result_counts[:locale_groups][survey_locale_group.id] = answers_rows.count
      end
    else
      scheduled_report_survey_locale_groups = @scheduled_report.scheduled_report_survey_locale_groups.joins(:survey_locale_group)
      scheduled_report_survey_locale_groups.order('locale_groups.created_at').each do |scheduled_report_survey_locale_group|
        @partially_selected_report = scheduled_report_survey_locale_group
        survey_locale_group = scheduled_report_survey_locale_group.survey_locale_group
        report_xlsx_urls[:locale_groups][survey_locale_group.id] = create_report(survey_locale_group)
        @report_result_counts[:locale_groups][survey_locale_group.id] = answers_rows.count
      end
    end

    surveys = @scheduled_report.all_surveys ? @scheduled_report.account.surveys.where(survey_locale_group_id: nil) : @scheduled_report.surveys
    surveys.order(:created_at).each do |survey|
      report_xlsx_urls[:surveys][survey.id] = create_report(survey)
      @report_result_counts[:surveys][survey.id] = answers_rows.count

      # rubocop:disable Style/Next <-- The styleguide can take a hike -- We're troubleshooting here.
      if report_xlsx_urls[:surveys][survey.id].nil?
        tagged_logger.info "2774_investigation survey.id #{survey.id}"
        tagged_logger.info "2774_investigation answers_sql #{answers_sql}"
        tagged_logger.info "2774_investigation answers_rows.count: #{answers_rows.count}"
      end
    end

    report_xlsx_urls
  end

  def create_report(reportee)
    tagged_logger.info "Setting a pile of variables"

    @num_surveys_examined += 1
    set_variables(reportee)
    tagged_logger.info('No impression. Skipped generation of report') and return nil unless @blended_impression_size.positive?

    package = generate_xlsx
    @axlsx_packages << package

    tagged_logger.info "Serializing report"
    package.serialize(xlsx_filepath)
    tagged_logger.info "Uploading report"
    @file_url = upload_xlsx_file

    @filepaths << xlsx_filepath

    @file_url
  end

  def set_variables(reportee)
    @today        = Date.today.to_s
    @reportee     = reportee
    @account      = @reportee.account
    @date_range   = @scheduled_report.parse_date_range
    @filters = {}
    @filters[:date_range] = @date_range if @date_range.present?

    @answers      = @reportee.answers
    @answers      = @answers.where(created_at: @date_range) if @date_range

    compute_survey_stats
  end

  def email_params
    super.merge(
      reportee: @reportee,
      scheduled_report_id: @scheduled_report.id,
      emails: @emails,
      attach_csv_file: attach_csv_file_to_email?,
      individual_rows_report_path: individual_rows_filepath,
      report_csv_url: @report_csv_urls[localized_report? ? :locale_groups : :surveys].values.first
    )
  end

  def xlsx_filename
    "Pulse Insights Report - #{@scheduled_report.name.gsub('/', ' ')} - #{@reportee.name.gsub('/', ' ')} #{@today}.xlsx"
  end
end
