# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class SetDeviceDataWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(udid, device_data)
    @udid = udid
    @device_data = device_data
    @identifier = device_data.delete('identifier')

    CreateDeviceWorker.new.perform(@udid)

    sql = select_sql_query
    log sql, 'DEBUG'
    sql = postgres_execute(sql)

    if sql.any?
      device_id = sql.first['device_id']
      account_id = sql.first['account_id']

      old_device_data = JSON.parse sql.first['device_data']
      @device_data = JSON.dump(old_device_data.merge(@device_data))

      sql = <<-SQL
        UPDATE "device_data"
          SET "device_data" = '#{PG::Connection.escape(@device_data)}'::jsonb,
              "updated_at" = now() AT TIME ZONE 'utc'
          WHERE "device_data"."account_id" = #{account_id} AND "device_data"."device_id" = #{device_id};
      SQL
    else
      sql = insert_sql_query
    end

    log sql, 'DEBUG'

    postgres_execute(sql)
  ensure
    postgres_disconnect!
  end

  def insert_sql_query
    device_data = JSON.dump(@device_data)

    <<-SQL
      INSERT INTO "device_data" ("account_id", "device_id", "device_data", "created_at", "updated_at")
        (SELECT *,'#{PG::Connection.escape(device_data)}'::jsonb, now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
          FROM
            (SELECT "accounts"."id" FROM "accounts" WHERE "accounts"."identifier" = '#{PG::Connection.escape(@identifier)}') AS account_id,
            (SELECT "devices"."id" FROM "devices" WHERE "devices"."udid" = '#{PG::Connection.escape(@udid)}') AS device_id) RETURNING id;
    SQL
  end

  def select_sql_query
    <<-SQL
      SELECT "device_data"."device_data", "device_data"."account_id", "device_data"."device_id"
        FROM "device_data"
        LEFT JOIN "accounts" ON "accounts"."id" = "device_data"."account_id"
        LEFT JOIN "devices" ON "devices"."id" = "device_data"."device_id"
        WHERE "devices"."udid" = '#{PG::Connection.escape(@udid)}' AND "accounts"."identifier" = '#{PG::Connection.escape(@identifier)}';
    SQL
  end
end
