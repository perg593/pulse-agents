# frozen_string_literal: true
require "google/cloud/storage"

module NYULangone
  NYU_LANGONE_ACCOUNT_IDENTIFIER = "PI-19699623"
  BRAND_NAME = "NYULangone"

  GOOGLE_CLOUD_PROJECT_ID = "nyu-langone-health-global"
  GOOGLE_CLOUD_BUCKET_NAME = "nyulh_pulse_insights_prod"

  class NYULangoneWorker
    include Sidekiq::Worker
    include Common
    include Report
    include ClientReports::StatusLogger

    def perform(start_date: nil, end_date: nil, dry_run: false, historical: false)
      tagged_logger.info "Started"

      report_data_start_date = start_date&.beginning_of_day || 1.day.ago.beginning_of_day
      report_data_end_date = end_date&.end_of_day || report_data_start_date.end_of_day

      report_data_range = (report_data_start_date..report_data_end_date)

      @account = Account.find_by(identifier: NYU_LANGONE_ACCOUNT_IDENTIFIER)
      @include_ip_column = @account.ip_storage_policy != "store_none" # Used by csv generator

      @report_filename = if historical
        "PulseInsights_#{BRAND_NAME}_historical.csv"
      else
        "PulseInsights_#{BRAND_NAME}_#{Time.current.strftime("%d%m%y")}.csv"
      end

      tagged_logger.info "Generating report for #{report_data_range} named #{@report_filename}"

      generate_submission_csv(report_data_range)

      upload_to_nyu_langone(report_filepath, @report_filename) unless dry_run
      upload_copy_to_s3(@report_filename)

      record_success(report_data_start_date)
    rescue StandardError => e
      tagged_logger.info "Error #{e.inspect}"
      Rollbar.error(e, "#{self.class.name} failed")

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
      false
    end

    # Override of Report's method
    def reportee_surveys
      @account.surveys
    end

    private

    def upload_to_nyu_langone(filepath, destination_file_name)
      storage = Google::Cloud::Storage.new(project_id: GOOGLE_CLOUD_PROJECT_ID, credentials: google_cloud_credentials)

      # skip_lookup: true is very important
      # lookup requires additional permission
      bucket = storage.bucket(GOOGLE_CLOUD_BUCKET_NAME, skip_lookup: true)

      bucket.create_file(filepath, destination_file_name)
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

    def google_cloud_credentials
      {
        type: "service_account",
        project_id: GOOGLE_CLOUD_PROJECT_ID,
        private_key_id: "2539a8f08381b58aa7dfa79893d3ef401dddbe49",
        private_key: Rails.application.credentials.nyu_langone.google_cloud_storage.private_key,
        client_email: "pulseinsights@nyu-langone-health-global.iam.gserviceaccount.com",
        client_id: "115918883399669073736",
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/pulseinsights%40nyu-langone-health-global.iam.gserviceaccount.com",
        universe_domain: "googleapis.com"
      }
    end
  end
end
