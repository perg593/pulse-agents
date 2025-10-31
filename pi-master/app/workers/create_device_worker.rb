# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class CreateDeviceWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(udid, client_key = nil)
    udid = udid ? udid[0..254] : ''

    unless valid_udid?(udid)
      log("Invalid UDID: #{udid}", 'DEBUG')
      return {}
    end

    sql = <<-SQL
      WITH "new_device" AS (
        INSERT INTO "devices" ("udid", "client_key", "created_at", "updated_at")
        SELECT '#{PG::Connection.escape(udid)}', #{client_key_value(client_key)}, (now() at time zone 'utc'), (now() at time zone 'utc')
        WHERE NOT EXISTS (SELECT "devices"."id" FROM "devices" WHERE "udid" = '#{PG::Connection.escape(udid)}')
        RETURNING id
      )
      SELECT "id" FROM "new_device"
      UNION
      SELECT "devices"."id" FROM "devices" WHERE "udid" = '#{PG::Connection.escape(udid)}';
    SQL

    device = {}

    postgres_execute(sql).each_row do |row|
      device[:id] = row[0].to_i
      device[:udid] = udid
      device[:client_key] = client_key
    end

    device
  ensure
    postgres_disconnect!
  end

  def client_key_value(client_key)
    if client_key
      <<-SQL
        '#{PG::Connection.escape(client_key)}'
      SQL
    else
      <<-SQL
        null
      SQL
    end
  end

  def valid_udid?(udid)
    # TODO: upgrate the Ruby version to 2.5 https://www.ruby-lang.org/en/news/2019/03/31/support-of-ruby-2-3-has-ended/
    # udid.match?(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
    !!(udid =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
  end
end
