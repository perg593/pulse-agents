# frozen_string_literal: true

require 'csv'

class AstraZenecaWorker
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

    report_filename = "#{custom_filename || "astrazeneca_pulseinsights_data_#{timestamp}"}.csv"
    report_filepath = "tmp/#{report_filename}"

    control_filename = "#{custom_control_filename || "astrazeneca_pulseinsights_qc_#{timestamp}"}.csv"
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

  def generate_report(report_filepath)
    CSV.open(report_filepath, 'w', col_sep: '|') do |csv|
      csv << answer_mapper.keys
      @logger.info "Found #{answers_rows.count} result rows"
      answers_rows.each { |answer| csv << answer_mapper(answer).values }
    end

    @logger.info "Report generated"
  end

  def generate_control_file(report_filename, report_filepath, control_filepath)
    CSV.open(control_filepath, 'w') do |csv|
      data_period_start, data_period_end = [report_start_date, report_end_date].map { |date| date.strftime("%Y-%m-%d") }

      report_file = File.open(report_filepath)
      report_filesize = report_file.size

      sha256 = Digest::SHA256.file(report_file)
      report_checksum = sha256.hexdigest

      report_file.close

      quality_control_data = {
        "Feed_Name" => report_filename,
        "Record_Count" => answers_rows.count,
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

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def answer_mapper(answer = {})
    {
      "Account Name" => answer['name'],
      "Account ID" => answer['identifier'],
      'Survey Website' => answer['survey_website'],
      "WEC ID" => answer['wec_id'],
      "Date" => answer['date'],
      "Time" => answer['time'],
      "Timestamp (UTC)" => answer['timestamp'],
      "Question" => answer['question'],
      "Response" => answer['response'],
      "Tags" => answer['tags'],
      "SurveyID" => answer['survey_id'],
      'Previous Surveys' => answer["previous_surveys"],
      "QuestionID" => answer['question_id'],
      "ResponseID" => answer['response_id'],
      "NextQuestionID" => answer['next_question_id'],
      "Pageview Count" => answer['pageview_count'],
      "Visit Count" => answer['visit_count'],
      "Device Type" => answer['device_type'],
      "DeviceUDID" => answer['udid'],
      "Client Key" => answer['client_key'],
      "Completion URL" => answer['url'],
      "View Name" => answer['view_name'],
      "Event" => answer['pseudo_event'],
      "Context data" => parse_custom_data(answer['custom_data']).except('adobeID').to_s,
      "Device data" => answer['device_data'],
      "Sentiment Score" => answer['score'],
      "Sentiment Magnitude" => answer['magnitude'],
      "Entity 1 name" => answer['entity_1_name'],
      "Entity 1 type" => answer['entity_1_type'],
      "Entity 2 name" => answer['entity_2_name'],
      "Entity 2 type" => answer['entity_2_type'],
      "Entity 3 name" => answer['entity_3_name'],
      "Entity 3 type" => answer['entity_3_type'],
      "Entity 4 name" => answer['entity_4_name'],
      "Entity 4 type" => answer['entity_4_type'],
      "OS" => answer['os'],
      "Browser" => answer['browser'],
      "Browser version" => answer['browser_version']&.strip,
      "Channel" => answer['channel'],
      "AdobeID" => parse_custom_data(answer['custom_data'])['adobeID']
    }
  end
end
