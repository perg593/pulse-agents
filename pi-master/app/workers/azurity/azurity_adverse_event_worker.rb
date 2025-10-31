# frozen_string_literal: true

module Azurity
  class AzurityAdverseEventWorker
    include Sidekiq::Worker
    include Common
    include Report

    def perform(account_identifier, submission_udid, dry_run: false)
      tagged_logger.info "Started #{dry_run ? "DRY RUN" : ""}"

      tagged_logger.info "Looking up account #{account_identifier}"
      @account = Account.find_by_identifier(account_identifier)

      tagged_logger.info "Looking up submission #{submission_udid}"
      @submission = Submission.find_by(udid: submission_udid)

      unless @account && @submission
        tagged_logger.info "Account or submission not found -- aborting"
        raise ArgumentError, "AzurityAdverseEventWorker missing account or submission"
      end

      brand_name = AZURITY_CONFIG[:azurity_accounts].detect { |account_info| account_info[:account_id] == @account.id }[:brand_name]
      index = WorkerOutputCopy.for_worker(self.class).where("DATE(created_at) = ?", Time.current.to_date).count
      @report_filename = "PulseInsights_#{brand_name}_#{Time.current.strftime("%d%m%y")}_#{index}.csv"

      @include_ip_column = @account.ip_storage_policy != "store_none" # Used by csv generator

      tagged_logger.info "Generating report for #{submission_udid} named #{@report_filename}"
      generate_submission_csv

      upload_to_azurity unless dry_run
      upload_copy_to_s3(@report_filename)
    rescue StandardError => e
      tagged_logger.info "Error #{e.inspect}"
      Rollbar.error(e, "AzurityAdverseEventWorker failed")
    ensure
      tagged_logger.info "Finished"
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
      @account.surveys.where(id: @submission.survey_id)
    end

    private

    def upload_to_azurity
      return unless %w(production).include? Rails.env

      tagged_logger.info "Uploading to Azurity via SFTP"

      azurity_credentials = Rails.application.credentials.azurity[:adverse_events]

      Net::SFTP.start(azurity_credentials[:host], azurity_credentials[:user], {password: azurity_credentials[:password]}) do |sftp|
        sftp.upload!(report_filepath, "/#{@report_filename}")
      end
    end

    # We need data from the standard "Individual Rows" sheet in scheduled reports
    def generate_submission_csv
      # Prerequisites for Report's methods
      @filters = {
        submission_id: @submission.id
      }

      individual_rows_csv
    end

    def report_filepath
      "tmp/#{@report_filename}"
    end
  end
end
