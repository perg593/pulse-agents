# frozen_string_literal: true

# This worker sends answer data to Comcast server every hour
class MeleeWorker
  include Sidekiq::Worker
  include Common
  include ClientReports::StatusLogger

  ACCOUNT_ID = 191 # Comcast SpeedTest

  def perform(start_time: nil, end_time: nil)
    tagged_logger.info 'Started'
    @end_time = end_time || Time.current.in_time_zone('America/New_York')
    start_time ||= @end_time - 1.hour

    tagged_logger.info "start_time: #{start_time}, end_time: #{@end_time}"

    answers = Account.find(ACCOUNT_ID).answers.where(created_at: start_time..@end_time)
    tagged_logger.info "Answer Count: #{answers.count}"

    answers.find_in_batches(batch_size: 500).each do |batch|
      melee_data = batch.map { |answer| melee_datum(answer) }
      send_melee_data(melee_data)
      log_melee_data(melee_data)
    end

    save_melee_data if last_run_in_a_day?

    record_success(start_time)
  rescue StandardError => e
    tagged_logger.error e
    Rollbar.error(e, "Comcast Speedtest Data Export")

    record_failure(start_time)
  ensure
    tagged_logger.info 'Finished'
  end

  def self.delivered_all_for_date?(date)
    (0..23).all? do |i|
      data_start_time = date.in_time_zone('America/New_York').beginning_of_day + i.hours

      delivered_as_expected?(data_start_time)
    end
  end

  def self.delivered_as_expected?(data_start_time = nil)
    data_start_time ||= Time.current.in_time_zone('America/New_York').beginning_of_hour - 1.hours

    ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
  end

  private

  def melee_datum(answer)
    {
      'appname': "pulse-survey",
      'appVersion': "2.0",
      'partner': "speedtest",
      'en': "Survey submission, #{answer.submission.survey_id}",
      'timeStamp': @end_time.to_datetime.to_s,
      'surveyID': answer.submission.survey_id,
      'Question': answer.question_content,
      'questionID': answer.question_id,
      'Response': answer.possible_answer_content || answer.text_answer,
      'responseID': answer.possible_answer_id,
      'Pageview Count': answer.submission.pageview_count,
      'Visit Count': answer.submission.visit_count,
      'IP Address': answer.ip_address,
      'Device Type': answer.submission.device_type,
      'DeviceUDID': answer.device.udid,
      'Client Key': answer.device.client_key,
      'Completion URL': answer.url,
      'Context Data': answer.custom_data,
      'Previous Surveys': answer.previous_surveys,
      'OS': answer.os,
      'Browser': answer.browser,
      'Browser Version': answer.browser_version
    }
  end

  def send_melee_data(melee_data)
    tagged_logger.info 'Sending Melee data'

    res = Retryable.with_retry(logger: tagged_logger) do
      RestClient::Request.execute(method: :post, url: endpoint, payload: melee_data.to_json, headers: header, log: tagged_logger)
    end

    tagged_logger.info "Response code: #{res.code}"
  end

  def log_melee_data(melee_data)
    File.open(melee_data_filepath, 'a') { |f| f.write melee_data.to_json }
  end

  def save_melee_data
    File.write(melee_data_filepath, 'No Data'.to_json) unless File.exist?(melee_data_filename)
    upload_copy_to_s3(melee_data_filename)
  end

  def melee_data_filepath
    "tmp/#{melee_data_filename}"
  end

  # hours and minutes are truncated because there's only one file for each day
  def melee_data_filename
    "melee_#{@end_time.strftime("%Y_%m_%d")}.json"
  end

  def endpoint
    'https://melee.sed.dh.comcast.net/v2/event/speedtest'
  end

  def header
    { "melee-token" => Rails.application.credentials.melee[:token], "Content-Type" => 'application/json', "Content" => 'application/json' }
  end

  # Consolidate results of each run into 1 file because it'd flood the worker output summary email otherwise
  def last_run_in_a_day?
    1.hour.from_now >= Date.tomorrow.beginning_of_day
  end
end
