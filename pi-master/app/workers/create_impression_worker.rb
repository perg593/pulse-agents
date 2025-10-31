# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class CreateImpressionWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def perform(params)
    # Truncate all the data to the table limits
    @url = params['url'] ? params['url'][0..9999] : ''
    # Converting the URLs themselves is causing Waterworks frustration
    @url = CGI.unescape(@url) if @url.downcase.include?("waterworks")

    @user_agent  = params['user_agent'] ? params['user_agent'][0..9999] : ''
    @survey_id   = params['survey_id']
    @udid        = params['udid'] ? params['udid'][0..254] : ''
    @device_type = params['device_type'] ? params['device_type'][0..254] : ''
    @visit_count = params['visit_count'] || '1'
    @device      = params['device']
    @client_key  = params['client_key']
    @pageview_count = params['pageview_count'] || '1'
    @pseudo_event   = params['pseudo_event'] ? params['pseudo_event'][0..9999] : ''

    @ip_address  = params['ip_address'] ? params['ip_address'][0..254] : ''
    @ip_address  = obfuscate_ip_address(@ip_address, @survey_id)

    begin
      @custom_data = params['custom_data'] ? JSON.dump(JSON.parse(params['custom_data'])) : '{}'
    rescue StandardError => e
      @custom_data = '{}'
    end

    sql = insert_sql_query

    log sql, 'DEBUG'

    impression = {}

    postgres_execute(sql).each_row do |row|
      impression[:id] = row[0].to_i
    end

    DeleteExcessiveImpressionsWorker.perform_async(@device[:id])

    impression
  ensure
    postgres_disconnect!
  end

  def insert_sql_query
    <<-SQL
      INSERT INTO "submissions" ("survey_id", "device_id", "udid", "url", "pseudo_event", "ip_address", "user_agent", "answers_count", "custom_data", "device_type", "visit_count", "pageview_count", "client_key", "created_at") VALUES
        (#{PG::Connection.escape(@survey_id.to_s).to_i},
        #{PG::Connection.escape(@device[:id].to_s).to_i},
        '#{PG::Connection.escape(@udid)}',
        '#{PG::Connection.escape(@url)}',
        '#{PG::Connection.escape(@pseudo_event)}',
        '#{PG::Connection.escape(@ip_address)}',
        '#{PG::Connection.escape(@user_agent)}',
        0,
        '#{PG::Connection.escape(@custom_data)}'::json,
        '#{PG::Connection.escape(@device_type)}',
        #{PG::Connection.escape(@visit_count.to_s)}::integer,
        #{PG::Connection.escape(@pageview_count.to_s)}::integer,
        #{client_key_value}
        (now() at time zone 'utc'))
        RETURNING id;
    SQL
  end

  def client_key_value
    if @client_key
      <<-SQL
        '#{PG::Connection.escape(@client_key)}',
      SQL
    else
      <<-SQL
        null,
      SQL
    end
  end
end
