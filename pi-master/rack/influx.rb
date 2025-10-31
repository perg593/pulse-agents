# frozen_string_literal: true

# rubocop:disable Metrics/CyclomaticComplexity

require File.join(File.dirname(__FILE__), '../lib/influxdb_client')

module Rack
  module Influx
    include PiLogger

    BATCH_SIZE = 100
    SEND_EVERY_SECONDS = 60

    def influxdb_connect!
      @influx_client = InfluxDBClient.new
    end

    def send_transmissions_to_influx_every_second
      return unless Rack::IntegrationSwitch.integration_enabled?('influxdb_transmission')

      Thread.new do
        last_batch_sent_at = Time.now.to_i
        loop do
          if @influxdb_batch.size > BATCH_SIZE || last_batch_sent_at < (Time.now.to_i - SEND_EVERY_SECONDS)
            batch = @influxdb_batch.dup
            @influxdb_batch = []

            # I really want to rescue Exception in this block
            # rubocop:disable Lint/RescueException
            begin
              points = influxdb_points(batch)
              write_to_influxdb(points)
            rescue Exception => e
              log " !!! Error writing to InfluxDB: #{e.inspect}"
              log points.to_s

              @influxdb_batch = batch
            end
            # rubocop:enable Lint/RescueException

            last_batch_sent_at = Time.now.to_i
          end

          sleep 1
        end
      end
    end

    # For each call, store the time into array
    def log_time_influxdb(request_path, serie)
      time = ((Time.now - @start_time) * 1000 * 100).to_i.to_f / 100.0
      endpoint = clean_endpoint(request_path)
      identifier = clean_identifier(@identifier)

      @influxdb_batch << [identifier, endpoint, time, serie]
    end

    def write_to_influxdb(points)
      @influx_client.influxdb.write_points(points)
    end

    def influxdb_points(batch)
      data = batch.map { |req| ["#{req[0]}_#{req[1]}_#{req[3]}", req[0], req[1], req[2], req[3]] }.group_by(&:first).map do |k, v|
        values = v.map { |d| { account_id: d[1], endpoint: d[2], time: d[3], series: d[4] } }.flatten
        {k => values}
      end

      # For each pair of endpoint/account_id, calculate the avg, min and max
      data.map do |d|
        values = d.values.flatten
        times = values.map { |h| h[:time] }.compact

        {
          series: values.first[:series],
          tags:
            {
              account_id: values.first[:account_id],
              endpoint: values.first[:endpoint],
              hostname: @hostname
            },
          values:
            {
              min: times.min.round(2),
              max: times.max.round(2),
              avg: (times.inject(:+) / times.size).round(2),
              count: times.size
            }
        }
      end
    end

    def clean_endpoint(endpoint)
      case endpoint
      when '/serve', '/direct_serve', '/results', '/present_results', '/track_event', '/custom_content_link_click', '/heartbeat'
        endpoint.sub('/', '')
      when /^\/surveys\/([0-9]+)\/questions/
        'questions'
      when /^\/surveys\/([0-9]+)\/poll/
        'poll'
      when /^\/surveys\/([0-9]+)/
        'present_survey'
      when /^\/surveys\/([-a-zA-Z0-9]+)/
        'present_event'
      when /^\/submissions\/email_answer/
        'answer_email'
      when /^\/submissions\/([-a-zA-Z0-9]+)\/answer/
        'answer'
      when /^\/submissions\/([-a-zA-Z0-9]+)\/all_answers/
        'answer_all'
      when /^\/submissions\/([-a-zA-Z0-9]+)\/viewed_at/
        'viewed_at'
      when /^\/submissions\/([-a-zA-Z0-9]+)\/close/
        'close'
      when /^\/q\/([0-9]+)/
        'direct_submission'
      when /^\/devices\/([-a-zA-Z0-9]+)\/set_data/
        'set_data'
      else
        'other'
      end
    end

    def clean_identifier(identifier)
      identifier =~ /^PI-\d{8}\z/ ? identifier : 'other'
    end
  end
end

# rubocop:enable Metrics/CyclomaticComplexity
