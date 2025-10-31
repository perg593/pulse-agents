# frozen_string_literal: true
module Rack
  module DatabaseTriggers
    def survey_triggering_rules(preview_mode:, direct_submission: false)
      # surveys.status(1) == "live"
      if preview_mode
        # In Preview Mode, display surveys in status LIVE or DRAFT and ignore sampling rate
        <<-SQL
          (("surveys"."status" = 1) OR ("surveys"."status" = 0)) AND #{survey_date_rules}
        SQL
      elsif direct_submission
        <<-SQL
          "surveys"."status" = 1 AND #{survey_date_rules}
        SQL
      else
        # https://www.postgresql.org/docs/11/functions-math.html#FUNCTIONS-MATH-RANDOM-TABLE
        #
        # RANDOM function returns a random value in the range 0.0 <= x < 1.0
        <<-SQL
          "surveys"."status" = 1 AND
          #{survey_date_rules} AND
          ("surveys"."sample_rate" IS NULL OR ((RANDOM() * 99 + 1) < "surveys"."sample_rate"))
        SQL
      end
    end

    def device_data_sql_is(trigger)
      "\"device_data\".\"device_data\" @> '{\"#{trigger['device_data_key']}\": \"#{trigger['device_data_value']}\"}'"
    end

    def device_data_sql_is_not(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}') != '#{trigger['device_data_value']}'"
    end

    def device_data_sql_contains(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}') LIKE '%#{trigger['device_data_value']}%'"
    end

    def device_data_sql_does_not_contain(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}') NOT LIKE '%#{trigger['device_data_value']}%'"
    end

    def device_data_sql_is_more_than(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}')::integer > #{trigger['device_data_value']}::integer"
    end

    def device_data_sql_is_equal_or_more_than(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}')::integer >= #{trigger['device_data_value']}::integer"
    end

    def device_data_sql_is_less_than(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}')::integer < #{trigger['device_data_value']}::integer"
    end

    def device_data_sql_is_equal_or_less_than(trigger)
      "(\"device_data\".\"device_data\"->>'#{trigger['device_data_key']}')::integer <= #{trigger['device_data_value']}::integer"
    end

    def device_data_sql_is_true(trigger)
      "\"device_data\".\"device_data\" ?| array['#{trigger['device_data_key']}']"
    end

    def device_data_sql_is_not_true(trigger)
      "(NOT \"device_data\".\"device_data\" ?| array['#{trigger['device_data_key']}'])"
    end

    def survey_date_rules
      <<-SQL
        ("surveys"."starts_at" IS NULL OR (("surveys"."starts_at" AT TIME ZONE 'UTC') < (NOW() AT TIME ZONE 'UTC'))) AND
        ("surveys"."ends_at" IS NULL OR (("surveys"."ends_at" AT TIME ZONE 'UTC') > (NOW() AT TIME ZONE 'UTC')))
      SQL
    end
  end
end
