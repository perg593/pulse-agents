# frozen_string_literal: true

require 'csv'

module PeriodicReportWorkers
  class BenMooreWorker
    include Sidekiq::Worker
    include ::Common
    include PeriodicReportWorkers::Common
    include ClientReports::StatusLogger

    S3_CONFIG = {
      region: "us-west-2",
      bucket_path: "",
      bucket_name: "pi-reports"
    }.freeze

    def perform(
      start_date: nil, end_date: nil,
      custom_report_filename: nil, custom_qc_filename: nil
    )
      tagged_logger.info 'Started'

      qc_filename = custom_qc_filename || "benjaminmoore_pulseinsights_qc_#{Time.current.strftime("%y%m%d")}.csv"
      qc_filepath = "tmp/#{qc_filename}"

      report_filename = custom_report_filename || "benjaminmoore_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv"
      report_filepath = "tmp/#{report_filename}"

      report_data_start_date = start_date&.beginning_of_day || 1.month.ago.beginning_of_month
      report_data_end_date = end_date&.end_of_day || report_data_start_date.end_of_month
      report_data_range = (report_data_start_date..report_data_end_date)

      generate_submission_report(report_filepath, report_data_range)
      generate_qc_file(qc_filepath, report_filename, report_data_range, report_filepath)

      tagged_logger.info "Uploading to S3"

      report_file_url = transfer_to_s3(report_filename, S3_CONFIG, credentials: Aws.config[:credentials])
      qc_file_url = transfer_to_s3(qc_filename, S3_CONFIG, credentials: Aws.config[:credentials])

      ReportMailer.benjamin_moore_notification(report_file_url, qc_file_url).deliver_now

      record_success(report_data_start_date)
    rescue StandardError => e
      record_failure(report_data_start_date)
    ensure
      tagged_logger.info 'Finished'
    end

    def self.account_ids
      [
        174 # Benjamin Moore (PI-53817864)
      ]
    end

    # data_start_time -- the beginning of a month
    def self.delivered_as_expected?(data_start_time = 1.month.ago.beginning_of_month)
      ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
    end
  end
end
