# frozen_string_literal: true

require 'csv'

class NBAEmailSurveyWorker
  include Sidekiq::Worker
  include Common
  include Report
  include ClientReports::StatusLogger

  def perform(
    start_date: nil, end_date: nil,
    custom_report_filename: nil,
    dry_run: false
  )
    tagged_logger.info 'Started'

    @report_filename = custom_report_filename || "nba_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv"

    report_data_start_date = (start_date || 1.day.ago).beginning_of_day
    report_data_end_date = (end_date || report_data_start_date).end_of_day
    report_data_range = (report_data_start_date..report_data_end_date)

    generate_submission_csv(report_data_range)

    upload_to_nba unless dry_run
    upload_copy_to_s3(@report_filename)

    record_success(report_data_start_date)
  rescue StandardError => e
    record_failure(report_data_start_date)
  ensure
    tagged_logger.info 'Finished'
  end

  # data_start_time -- the beginning of a day
  def self.delivered_as_expected?(data_start_time = 1.day.ago.beginning_of_day)
    ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
  end

  def self.survey_ids
    [
      4972, # Email Capture Form | NBA Tickets | Inline | 2021-02-23
      4467 # Email Capture Form | NBA Tickets | Overlay | 2020-08-17
    ]
  end

  # We need data from the standard "Individual Rows" sheet in scheduled reports
  def generate_submission_csv(report_data_range)
    # Prerequisites for Report's methods
    @filters = {}
    @filters[:date_range] = report_data_range
    @filters[:market_ids] = self.class.survey_ids
    @date_range = report_data_range
    @market_ids = @filters[:market_ids]

    individual_rows_csv
  end

  # Override of Report's method
  def individual_rows_filepath
    report_filepath
  end

  # Override of Report's method
  def localized_report?
    false
  end

  # Override of Report's method
  def reportee_surveys
    Survey.where(id: self.class.survey_ids)
  end

  private

  def report_filepath
    "tmp/#{@report_filename}"
  end

  def upload_to_nba
    return unless %w(production).include? Rails.env

    tagged_logger.info 'Uploading to NBA via SFTP'

    credentials = Rails.application.credentials.nba[:sftp]

    Retryable.with_retry(interval: 60) do
      Net::SFTP.start(credentials[:host], credentials[:user], {password: credentials[:password]}) do |sftp|
        sftp.upload!(report_filepath, "/#{@report_filename}")
      end
    end
  end
end
