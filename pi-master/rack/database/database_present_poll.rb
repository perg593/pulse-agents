# frozen_string_literal: true

require_relative 'sql_helpers'

module Rack
  module DatabasePresentPoll
    def get_poll_enabled(survey_id, pi_identifier)
      sql = get_poll_enabled_sql(survey_id, pi_identifier)
      log sql, 'DEBUG'

      row = postgres_execute(sql).first

      return false if row.nil?

      row["poll_enabled"] == "t"
    end

    def get_poll_enabled_sql(survey_id, pi_identifier)
      <<-SQL
        SELECT poll_enabled FROM surveys
          INNER JOIN accounts ON accounts.id = surveys.account_id
          WHERE surveys.id = #{survey_id} AND
          accounts.identifier = '#{PG::Connection.escape(pi_identifier)}'
      SQL
    end
  end
end
