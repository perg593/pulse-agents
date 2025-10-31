# frozen_string_literal: true

require 'csv'

class AstraZenecaAggregateWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common
  include AstraZenecaCommon
  include ClientReports::StatusLogger

  sidekiq_options queue: :console

  def perform(start_date: nil, end_date: nil, custom_filename: nil, custom_control_filename: nil)
    worker_name = self.class.name.underscore
    @logger = Logger.new("log/#{worker_name}.log")

    @logger.info "Compiling AstraZeneca report"

    @start_date = start_date
    @end_date = end_date

    @date = Time.now.in_time_zone('America/New_York')

    @logger.info "Generating AstraZeneca report for #{@start_date && @end_date ? "#{@start_date} to #{@end_date}" : @date}"

    @az_accounts = ALL_AZ_ACCOUNTS
    @logger.info "Considering accounts #{@az_accounts.join(", ")}"

    timestamp = @date.strftime('%Y%m%d')

    report_filename = "#{custom_filename || "astrazeneca_pulseinsights_aggregatedata_#{timestamp}"}.csv"
    report_filepath = "tmp/#{report_filename}"

    control_filename = "#{custom_control_filename || "astrazeneca_pulseinsights_aggregate_qc_#{timestamp}"}.csv"
    control_filepath = "tmp/#{control_filename}"

    generate_report(report_filepath)
    generate_control_file(report_filename, report_filepath, control_filepath)

    upload_to_s3(report_filename)
    upload_to_s3(control_filename)

    record_success(report_start_date)
  rescue StandardError => e
    record_failure(report_start_date)
  ensure
    @logger.info "Finished"
  end

  # data_start_time -- the beginning of a day
  def self.delivered_as_expected?(data_start_time = 1.day.ago.beginning_of_day)
    ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
  end

  private

  def report_sql
    <<-SQL
      SELECT *,
        #{wec_id_sql}
        FROM (
          SELECT
            accounts.name account_name,
            accounts.identifier identifier,
            surveys.id survey_id,
            surveys.name survey_name
          FROM accounts
          LEFT JOIN surveys ON surveys.account_id = accounts.id
          WHERE accounts.id IN (#{@az_accounts.join(', ')})
          ORDER BY account_name DESC
        ) s;
    SQL
  end

  def aggregated_results
    @aggregated_results ||= postgres_execute(report_sql)
  end

  def submission_data
    submission_sql = <<-SQL
      COALESCE(SUM(1), 0) AS impression_count,
      COALESCE(SUM(CASE WHEN viewed_at IS NULL THEN 0 ELSE 1 END), 0) AS viewed_impression_count,
      COALESCE(SUM(CASE WHEN answers_count = 0 THEN 0 ELSE 1 END), 0) AS submission_count
    SQL

    @submission_data ||= Submission.
                         select(submission_sql).
                         where(survey_id: Survey.where(account_id: @az_accounts), created_at: (report_start_date..report_end_date)).
                         group(:survey_id)
  end

  def generate_report(report_filepath)
    CSV.open(report_filepath, 'w', col_sep: '|') do |csv|
      csv << survey_mapper.keys
      @logger.info "Found #{aggregated_results.count} result rows"
      aggregated_results.each { |survey| csv << survey_mapper(survey).values }
    end

    @logger.info "Report generated"
  end

  def generate_control_file(report_filename, report_filepath, control_filepath)
    CSV.open(control_filepath, 'w') do |csv|
      data_period_start, data_period_end = [report_start_date, report_end_date].map { |date| date.strftime("%m-%d-%y") }

      report_file = File.open(report_filepath)
      report_filesize = report_file.size

      sha256 = Digest::SHA256.file(report_file)
      report_checksum = sha256.hexdigest

      report_file.close

      quality_control_data = {
        "Feed_Name" => report_filename,
        "Record_Count" => aggregated_results.count,
        "Feed_Size" => report_filesize,
        "Checksum" => report_checksum,
        "Data_Period_Start" => data_period_start,
        "Data_Period_End" => data_period_end
      }

      csv << quality_control_data.keys
      csv << quality_control_data.values
    end

    @logger.info "Quality control file generated"
  end

  def survey_mapper(survey = {})
    submission_data_for_survey = submission_data.find_by(survey_id: survey['survey_id'])

    {
      "Account Name" => survey['account_name'],
      "Account ID" => survey['identifier'],
      "WEC ID" => survey['wec_id'],
      "Date" => report_start_date.strftime("%m/%d/%y"),
      "SurveyID" => survey['survey_id'],
      "Survey Name" => survey['survey_name'],
      "Impressions" => submission_data_for_survey&.impression_count.to_i,
      "Viewed Impressions" => submission_data_for_survey&.viewed_impression_count.to_i,
      "Submissions" => submission_data_for_survey&.submission_count.to_i
    }
  end
end
