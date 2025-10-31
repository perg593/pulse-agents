# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class UpdateClientKeyWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(device_id, client_key)
    sql = <<-SQL
      UPDATE "devices" SET "client_key"='#{PG::Connection.escape(client_key)}' WHERE "devices"."id"=#{device_id};
    SQL

    postgres_execute(sql)
  ensure
    postgres_disconnect!
  end
end
