# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class UpdateCloseByUserWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(submission_udid)
    log submission_udid

    sql = <<-SQL
      UPDATE "submissions" SET "closed_by_user" = 't' WHERE "submissions".udid = '#{PG::Connection.escape(submission_udid)}';
    SQL

    log sql, 'DEBUG'

    postgres_execute(sql)
  ensure
    postgres_disconnect!
  end
end
