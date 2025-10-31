# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class SaveCustomDataWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(submission_udid, custom_data)
    begin
      custom_data =
        if custom_data.is_a? Hash
          JSON.dump(custom_data)
        else
          begin
            JSON.dump(JSON.parse(custom_data))
          rescue JSON::ParserError => e
            JSON.dump(JSON.parse(CGI.unescape(custom_data)))
          end
        end
    rescue StandardError => e
      log "Error parsing JSON custom data #{e.inspect}"
      custom_data = '{}'
    end

    sql = <<-SQL
      UPDATE "submissions" SET "custom_data" = '#{PG::Connection.escape(custom_data)}'::json WHERE "submissions".udid = '#{PG::Connection.escape(submission_udid)}';
    SQL

    log sql, 'DEBUG'
    postgres_execute(sql)
  ensure
    postgres_disconnect!
  end
end
