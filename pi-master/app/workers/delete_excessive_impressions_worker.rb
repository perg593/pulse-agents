# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class DeleteExcessiveImpressionsWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  IMPRESSION_LIMIT_PER_DEVICE = 200 # due to performance concerns and the defence against bots

  # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2420
  #   The "submissions" table needs to be cleaned up due to performance concerns and the defence against bots.
  #   We've come to opt for a reactive approach like this because the previous periodical approach caused a disk bloat issue.
  def perform(device_id)
    @device_id = device_id

    tagged_logger.info "Device ID: #{escaped_device_id}"

    tagged_logger.warn "Device not found" and return unless Device.exists?(device_id)

    tagged_logger.info "Deleted impressions: #{delete_excessive_impressions.count}" if excessive_impressions_exist?
  rescue => e # Suppressing errors so that retries don't occupy the primary db's connection pool
    tagged_logger.error e.inspect
    Rollbar.error(e, device_id: device_id)
  ensure
    postgres_disconnect!
  end

  private

  # Refraining from issuing a DELETE statement when possible to avoid superfluous load to the primary db as we have multiple servers
  def excessive_impressions_exist?
    postgres_execute(check_excessive_impressions_query, readonly: true).first['exceeded'] == 't'
  end

  def delete_excessive_impressions
    postgres_execute(delete_excessive_impressions_query)
  end

  def check_excessive_impressions_query
    <<-SQL
      SELECT
        COUNT(*) > #{IMPRESSION_LIMIT_PER_DEVICE} exceeded
      FROM
        submissions
      WHERE
        device_id = #{escaped_device_id}
        AND answers_count = 0
        AND viewed_at IS NULL;
    SQL
  end

  # Reduce the rows to half the limit(=100)
  # The rows are deleted from the oldest
  # The subquery looks redundant because PostgreSQL doesn't support LIMIT/OFFSET in DELETE
  # "RETURNING id" because PostgreSQL doesn't support aggregate functions in RETURNING
  def delete_excessive_impressions_query
    <<-SQL
      DELETE
      FROM
        submissions
      WHERE
        device_id = #{escaped_device_id}
        AND answers_count = 0
        AND viewed_at IS NULL
        AND created_at <= (
        SELECT
          created_at
        FROM
          submissions
        WHERE
          device_id = #{escaped_device_id}
          AND answers_count = 0
          AND viewed_at IS NULL
        ORDER BY
          created_at DESC
        LIMIT 1 OFFSET #{IMPRESSION_LIMIT_PER_DEVICE / 2})
       RETURNING id;
    SQL
  end

  def escaped_device_id
    PG::Connection.escape(@device_id.to_s).to_i
  end
end
