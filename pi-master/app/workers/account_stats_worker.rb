# frozen_string_literal: true

class AccountStatsWorker
  include Sidekiq::Worker
  include Common

  def perform
    tagged_logger.info 'Started'

    influx_client = InfluxDBClient.new

    # TODO: Debug why this regex doesn't work through the ruby client "WHERE account_id =~ /^PI-[\d]{8}$/". It works with the CLI /usr/bin/influx
    query = <<-SQL
      SELECT SUM(count) AS calls_count FROM pi WHERE account_id =~ /^PI-*/ AND endpoint = 'serve' GROUP BY account_id
    SQL

    influx_client.influxdb.query(query) do |_name, tags, points|
      identifier = tags['account_id']
      next unless identifier.match?(/^PI-\d{8}$/)

      tagged_logger.tagged("Identifier : #{identifier}") do
        tagged_logger.info 'Account Not Found' and next unless account_stat = AccountStat.find_by(identifier: identifier)
        tagged_logger.info "Before : #{account_stat.calls_count}"
        account_stat.update(calls_count: account_stat.calls_count_offset + points.first['calls_count'])
        tagged_logger.info "After : #{account_stat.reload.calls_count}"
      end
    end

    tagged_logger.info 'Finished'
  rescue => e
    Rollbar.error e
    tagged_logger.error "Error: #{e.full_message}"
  end
end
