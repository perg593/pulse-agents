# frozen_string_literal: true
module Rack
  module DatabaseSetters
    # Create impression
    # rubocop:disable Metrics/ParameterLists
    def create_impression(survey, device, url, ip_address, user_agent, custom_data = '{}', device_type = '', visit_count = nil, pageview_count = nil)
      # Truncate all the data to the table limits
      url = url[0..9999]
      user_agent = user_agent[0..9999]
      ip_address = ip_address ? ip_address[0..254] : ''
      visit_count ||= '0'
      pageview_count ||= '0'

      begin
        custom_data = custom_data ? JSON.dump(JSON.parse(custom_data)) : '{}'
      rescue StandardError => e
        log "Error parsing JSON custom data #{e.inspect}"
        custom_data = '{}'
      end

      sql = <<-SQL
        INSERT INTO "submissions" ("survey_id", "device_id", "url", "ip_address", "user_agent", "answers_count", "custom_data", "device_type", "visit_count", "pageview_count", "created_at")
          VALUES (#{PG::Connection.escape(survey[:id].to_s).to_i}, #{PG::Connection.escape(device[:id].to_s).to_i}, '#{PG::Connection.escape(url)}', '#{PG::Connection.escape(ip_address)}', '#{PG::Connection.escape(user_agent)}', 0, '#{PG::Connection.escape(custom_data)}'::json, '#{PG::Connection.escape(device_type)}', #{PG::Connection.escape(visit_count)}::integer, #{PG::Connection.escape(pageview_count)}::integer, (now() at time zone 'utc')) RETURNING id;
      SQL
      log sql, 'DEBUG'
      impression = {}
      postgres_execute(sql).each do |row|
        impression[:id] = row["id"].to_i
      end
      impression
    end

    # We trust the data here because this is used after post answer which checks the validity of submission_id
    def save_custom_data(submission_id, custom_data)
      begin
        custom_data = JSON.dump(JSON.parse(custom_data))
      rescue StandardError => e
        log "Error parsing JSON custom data #{e.inspect}"
        custom_data = '{}'
      end

      sql = <<-SQL
        UPDATE "submissions" SET "custom_data" = '#{PG::Connection.escape(custom_data)}'::json WHERE "submissions".id = #{PG::Connection.escape(submission_id.to_s).to_i};
      SQL
      log sql, 'DEBUG'
      postgres_execute(sql)
    end
  end
end
