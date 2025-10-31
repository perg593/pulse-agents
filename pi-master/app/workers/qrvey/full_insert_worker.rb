# frozen_string_literal: true

# This worker inserts to all the columns in the dataset through an S3 bucket that Qrvey data sync processes feed off of
module Qrvey
  class FullInsertWorker
    include Sidekiq::Worker
    include Common

    # Nowhere in the whole procedure is batched because 1 minute worth of data can only get so big even with traffic spikes in mind
    # Please use the rake task "send_qrvey_data_historically" to run retroactively for batching purposes
    def perform(custom_start_time: nil, custom_end_time: nil)
      # Rounding seconds for Qrvey SQL to avoid missing rows
      @start_time = custom_start_time || 1.minute.ago.beginning_of_minute
      @end_time = custom_end_time || Time.current.beginning_of_minute
      tagged_logger.info "start time: #{@start_time}, end time: #{@end_time}"

      tagged_logger.info "row count: #{qrvey_rows.count}"

      stream_csv_to_s3 do |csv|
        csv << qrvey_headers
        qrvey_rows.each { |row| csv << row.values }
      end
    rescue => e
      Rollbar.error e
      tagged_logger.error e
    end

    def stream_csv_to_s3
      return unless %w(production staging develop).include? Rails.env

      qrvey_s3 = Rails.application.credentials[:qrvey][:s3]
      aws_credentials =Aws::Credentials.new(qrvey_s3[:access_key_id], qrvey_s3[:secret_access_key])
      s3_interface = Aws::S3::Resource.new(region: qrvey_s3[:region], credentials: aws_credentials)
      s3_object = s3_interface.bucket(qrvey_s3[:bucket_name]).object(qrvey_filename)

      s3_object.upload_stream { |write_stream| yield CSV(write_stream) }
    end

    # Consider switching to Parquet for further performance improvement
    def qrvey_filename
      "qrvey-#{@start_time.strftime("%Y-%m-%d %H:%M")}~#{@end_time.strftime("%Y-%m-%d %H:%M")}.csv"
    end

    def qrvey_headers
      qrvey_rows.fields
    end

    def qrvey_rows
      @qrvey_rows ||= postgres_execute(qrvey_sql, readonly: true)
    end

    # @start_time and @end_time will be bound to craft a dynamic SQL
    def qrvey_sql
      ERB.new(File.read('./lib/sql/qrvey.sql.erb')).result(binding)
    end
  end
end
