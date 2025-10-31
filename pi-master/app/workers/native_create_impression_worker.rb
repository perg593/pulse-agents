# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class NativeCreateImpressionWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(params, device)
    # Truncate all the data to the table limits
    survey_id = params['survey_id']
    submission_udid = params['submission_udid']
    launch_times = params['launch_times']
    install_days = params['install_days']
    view_name = params['view_name'] ? params['view_name'][0..9999] : ''
    user_agent = params['user_agent'][0..9999]

    ip_address = params['ip_address'] ? params['ip_address'][0..254] : ''
    ip_address = obfuscate_ip_address(ip_address, survey_id)
    mobile_type = Submission.mobile_types[params['mobile_type']] || 'NULL'

    begin
      custom_data = params['custom_data'] ? JSON.dump(JSON.parse(params['custom_data'])) : '{}'
    rescue StandardError => e
      custom_data = '{}'
    end

    sql = native_create_impression_sql(survey_id, device[:id], submission_udid, view_name, ip_address, user_agent, custom_data, launch_times,
                                       install_days, mobile_type)
    log sql, 'DEBUG'

    impression = {}

    postgres_execute(sql).each_row do |row|
      impression[:id] = row[0].to_i
    end

    DeleteExcessiveImpressionsWorker.perform_async(device[:id])

    impression
  ensure
    postgres_disconnect!
  end

  def native_create_impression_sql(survey_id, device_id, submission_udid, view_name, ip_address, user_agent,
                                   custom_data, launch_times, install_days, mobile_type)
    <<-SQL
      INSERT INTO "submissions" ("survey_id", "device_id", "udid", "view_name", "ip_address", "user_agent", "answers_count", "custom_data",
      "device_type", "mobile_type", "mobile_launch_times", "mobile_days_installed", "created_at") VALUES
        (#{PG::Connection.escape(survey_id.to_s).to_i},
        #{PG::Connection.escape(device_id.to_s).to_i},
        '#{PG::Connection.escape(submission_udid)}',
        '#{PG::Connection.escape(view_name)}',
        '#{PG::Connection.escape(ip_address)}',
        '#{PG::Connection.escape(user_agent)}',
        0,
        '#{PG::Connection.escape(custom_data)}'::json,
        'native_mobile',
        #{mobile_type},
        #{launch_times || '0'}::integer,
        #{install_days || '0'}::integer,
        (now() at time zone 'utc')) RETURNING id;
    SQL
  end
end
