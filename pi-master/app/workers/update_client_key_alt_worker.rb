# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

# Alternative "UpdateClientKey" worker for /answer call with 'submission_udid' instead of 'device_id'
class UpdateClientKeyAltWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(submission_udid, client_key)
    sql = <<-SQL
      UPDATE  devices d
      SET     client_key = '#{PG::Connection.escape(client_key)}'
      FROM    (
                SELECT  device_id
                FROM    submissions
                WHERE   submissions.udid = '#{PG::Connection.escape(submission_udid)}'
              ) sub
      WHERE   d.id = sub.device_id;
    SQL

    log sql, 'DEBUG'
    response = postgres_execute(sql)
    log response

    sql = <<-SQL
      UPDATE "submissions"
      SET "client_key"='#{PG::Connection.escape(client_key)}'
      WHERE "submissions"."udid"='#{PG::Connection.escape(submission_udid)}';
    SQL

    log sql, 'DEBUG'
    response = postgres_execute(sql)
    log response

    response
  ensure
    postgres_disconnect!
  end
end
