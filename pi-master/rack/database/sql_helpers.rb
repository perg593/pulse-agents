# frozen_string_literal: true

module Rack
  module SQLHelpers
    def self.frequency_cap_join_sql
      <<-SQL
          LEFT OUTER JOIN "submissions" AS "cap_impressions"
          ON "cap_impressions"."viewed_at" IS NOT NULL
            AND "cap_impressions"."device_id" = "devices"."id"
            AND (
              "cap_impressions"."created_at"::TIMESTAMP +
              (
                "accounts"."frequency_cap_duration"::TEXT || ' ' ||
                "accounts"."frequency_cap_type"::TEXT
              )::INTERVAL > NOW() AT TIME ZONE 'UTC'
            )
      SQL
    end

    def self.frequency_cap_filter_sql(preview_mode)
      <<-SQL
          (
            frequency_cap_enabled IS FALSE OR
            frequency_cap_enabled IS NULL OR
            (frequency_cap_enabled IS TRUE AND frequency_cap_limit > cap_impressions_count) OR
            surveys.ignore_frequency_cap IS TRUE OR
            #{preview_mode ? 'TRUE' : 'FALSE'}
          )
      SQL
    end

    def self.ios_android_filter_sql(mobile_type)
      if mobile_type
        <<-SQL
          ("surveys"."#{mobile_type}_enabled" = 't')
        SQL
      else
        <<-SQL
          ("surveys"."ios_enabled" = 't' OR "surveys"."android_enabled" = 't')
        SQL
      end
    end
  end
end
