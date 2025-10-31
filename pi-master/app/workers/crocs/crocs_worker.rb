# frozen_string_literal: true

require "csv"
require "fileutils"

module Crocs
  class CrocsWorker
    include Sidekiq::Worker
    include Common
    include Report
    include ClientReports::StatusLogger

    def perform(
      start_date: nil, end_date: nil,
      historical: false,
      dry_run: false
    )
      tagged_logger.info "Started"

      report_data_start_date = start_date&.beginning_of_day || 1.day.ago.beginning_of_day
      report_data_end_date = end_date&.end_of_day || report_data_start_date.end_of_day
      report_data_range = (report_data_start_date..report_data_end_date)

      csv_info_list = generate_account_csv_files(report_data_range, historical)

      if !dry_run && csv_info_list.any?
        upload_collated_file(csv_info_list, historical)
      end

      record_success(report_data_start_date)
    rescue StandardError => e
      tagged_logger.info "Error #{e.inspect}"
      Rollbar.error(e, "CrocsWorker failed")

      record_failure(report_data_start_date)
    ensure
      tagged_logger.info "Finished"
    end

    # data_start_time -- the beginning of a day
    def self.delivered_as_expected?(data_start_time = 1.day.ago.beginning_of_day)
      ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
    end

    # Override of Report's method
    def individual_rows_filepath
      report_filepath
    end

    # Override of Report's method
    def localized_report?
      @account.surveys.any?(&:localized?)
    end

    # Override of Report's method
    def reportee_surveys
      @account.surveys
    end

    private

    def crocs_account_info
      CROCS_CONFIG[:crocs_accounts].detect { |account_info| account_info[:account_id] == @account.id }
    end

    def generate_account_csv_files(report_data_range, historical)
      csv_info_list = []

      CROCS_CONFIG[:crocs_accounts].each do |account_info|
        @account = Account.find(account_info[:account_id])

        tagged_logger.info "Processing Account(#{@account.id})"

        if @account.surveys.empty?
          tagged_logger.info "No surveys for account -- skipping"
          next
        end

        csv_file_info = generate_account_csv(report_data_range, historical)
        csv_info_list << csv_file_info if csv_file_info
      end

      csv_info_list
    end

    def generate_account_csv(report_data_range, historical)
      @include_ip_column = @account.ip_storage_policy != "store_none"
      brand_name = crocs_account_info[:brand_name]
      @reportee = "cache_buster_#{@account.id}"

      @report_filename = if historical
        "PulseInsights_#{brand_name}_historical.csv"
      else
        "PulseInsights_#{brand_name}_#{Time.current.strftime("%Y-%m-%d")}.csv"
      end

      tagged_logger.info "Generating report for #{report_data_range} named #{@report_filename}"

      generate_submission_csv(report_data_range)

      {
        filepath: report_filepath,
        brand_name: brand_name
      }
    end

    def upload_collated_file(csv_info_list, historical)
      collated_filename = if historical
        "pulse-survey-data_crocs-heydude_historical.csv"
      else
        "pulse-survey-data_crocs-heydude_#{Time.current.strftime("%Y-%m-%d")}.csv"
      end

      collate_csv_files(csv_info_list, collated_filename)
      upload_copy_to_s3(collated_filename)
      upload_collated_file_to_crocs(collated_filename)
    end

    def collate_csv_files(csv_info_list, collated_filename)
      tagged_logger.info "Collating #{csv_info_list.length} CSV files into #{collated_filename}"

      collated_filepath = "tmp/#{collated_filename}"

      # Use CSV library to properly handle the collation
      CSV.open(collated_filepath, 'w') do |collated_csv|
        first_file_processed = false

        csv_info_list.each do |csv_file|
          brand_name = csv_file[:brand_name]
          filepath = csv_file[:filepath]

          next unless File.exist?(filepath)

          # Check if the file has any data rows (more than just headers)
          next unless file_has_data_rows?(filepath)

          # Process each file with proper CSV handling
          CSV.foreach(filepath, headers: true) do |row|
            # Add brand name to each row
            row_with_brand = row.to_h.merge('Brand Name' => brand_name)

            # Write headers only once (from first file)
            unless first_file_processed
              collated_csv << row_with_brand.keys
              first_file_processed = true
            end

            # Write the data row
            collated_csv << row_with_brand.values
          end
        end
      end

      tagged_logger.info "Successfully collated CSV files into #{collated_filepath}"
      collated_filepath
    end

    def file_has_data_rows?(filepath)
      line_count = count_file_lines(filepath)
      line_count > 1
    end

    def count_file_lines(filepath)
      CSV.foreach(filepath, headers: false).count
    end

    def upload_collated_file_to_crocs(collated_filename)
      return unless %w(production).include? Rails.env

      tagged_logger.info "Uploading collated file to Crocs via SFTP"

      sftp_credentials = Rails.application.credentials.crocs[:sftp]

      Retryable.with_retry(interval: 60) do
        Net::SFTP.start(sftp_credentials[:host], sftp_credentials[:user], {password: sftp_credentials[:password]}) do |sftp|
          sftp.upload!("tmp/#{collated_filename}", "/#{collated_filename}")
        end
      end
    end

    # We need data from the standard "Individual Rows" sheet in scheduled reports
    def generate_submission_csv(report_data_range)
      # Prerequisites for Report's methods
      @filters = { date_range: report_data_range }
      @date_range = report_data_range

      individual_rows_csv
    end

    def report_filepath
      "tmp/#{@report_filename}"
    end
  end
end
