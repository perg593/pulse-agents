# frozen_string_literal: true
# rubocop:disable Metrics/ModuleLength

module Rack
  module DatabaseFilters
    # Filters survey with visit_count
    # Thie filter was moved from the big SQL in #get_surveys method because we now need the survey_id
    # We also need the client_key to sum the visit_count with the other visit_count from linked devices (through the submissions)
    # If client_key is missing we only perform with the current visit_count
    def filter_visits(visit_count, client_key, udid, survey_id)
      linked_visits = 0
      visit_count ||= 1

      if client_key
        sql = <<-SQL
          SELECT SUM(submissions.visit_count)
          FROM submissions
          LEFT JOIN devices ON devices.id = submissions.device_id
          WHERE submissions.client_key = '#{PG::Connection.escape(client_key)}' AND submissions.survey_id = '#{PG::Connection.escape(survey_id)}' AND devices.udid != '#{PG::Connection.escape(udid)}'
        SQL

        log sql, 'DEBUG'
        linked_visits = postgres_execute(sql).first['sum'].to_i if postgres_execute(sql).any? && postgres_execute(sql).first['sum']
      end

      all_visits_count = visit_count.to_i + linked_visits

      sql = <<-SQL
        SELECT COUNT(DISTINCT(triggers.id))
        FROM triggers
        WHERE triggers.survey_id = '#{PG::Connection.escape(survey_id)}' AND triggers.type_cd = 'VisitTrigger' AND
          ((#{all_visits_count || '0'}::integer < triggers.visits_count AND triggers.visitor_type = 2) OR
          (#{all_visits_count}::integer > 1 AND triggers.visitor_type = 1))
      SQL

      log sql, 'DEBUG'

      res = postgres_execute(sql).first['count'].to_i

      res.zero?
    end

    # Filters survey with previous answer trigger
    # Returns true if survey can be shown, otherwise, false
    def filter_previous_answer_survey(survey_id, udid, client_key = nil)
      triggers = filter_survey_get_answer_trigger(survey_id)

      return true unless triggers.any?

      trigger = triggers.first

      sql = <<-SQL
        SELECT answers.id FROM answers
        LEFT JOIN submissions ON answers.submission_id = submissions.id
        LEFT JOIN devices ON submissions.device_id = devices.id
      SQL

      where_sql =
        if client_key
          <<-SQL
            WHERE answers.possible_answer_id = '#{PG::Connection.escape(trigger['previous_possible_answer_id'])}' AND (devices.udid = '#{PG::Connection.escape(udid)}'
            OR devices.client_key = '#{PG::Connection.escape(client_key)}');
          SQL
        else
          <<-SQL
            WHERE answers.possible_answer_id = '#{PG::Connection.escape(trigger['previous_possible_answer_id'])}' AND devices.udid = '#{PG::Connection.escape(udid)}';
          SQL
        end

      sql += where_sql

      log sql, 'DEBUG'
      postgres_execute(sql).any?
    end

    def filter_survey_get_answer_trigger(survey_id)
      sql = <<-SQL
        SELECT "triggers"."previous_possible_answer_id" FROM "triggers"
        WHERE "triggers"."survey_id" = '#{PG::Connection.escape(survey_id)}' AND "triggers"."type_cd" = 'PreviousAnswerTrigger' AND "triggers"."previous_possible_answer_id" IS NOT NULL
          AND "triggers"."previous_answered_survey_id" IS NOT NULL;
      SQL

      log sql, 'DEBUG'
      postgres_execute(sql)
    end

    def device_data_filter_select_sql(udid, pi_identifier, client_key = nil)
      sql = <<-SQL
        SELECT device_data.id FROM device_data LEFT JOIN accounts ON accounts.id = device_data.account_id LEFT JOIN devices ON devices.id = device_data.device_id
      SQL

      sql += if client_key
        <<-SQL
          WHERE accounts.identifier = '#{PG::Connection.escape(pi_identifier)}' AND (devices.udid = '#{PG::Connection.escape(udid)}'
          OR devices.client_key = '#{PG::Connection.escape(client_key)}')
        SQL
      else
        <<-SQL
          WHERE accounts.identifier = '#{PG::Connection.escape(pi_identifier)}' AND devices.udid = '#{PG::Connection.escape(udid)}'
        SQL
      end
    end

    # Filters survey with device_data trigger
    # Returns true if survey can be shown, otherwise, false
    def filter_survey(survey_id, udid, pi_identifier, client_key = nil, custom_data = nil)
      triggers = filter_survey_get_triggers(survey_id)

      return true unless triggers.any?

      base_sql = device_data_filter_select_sql(udid, pi_identifier, client_key)

      if triggers.all? { |trigger| trigger["device_data_matcher"] == "is_not_true" }
        sql = base_sql
        sql += ";"
        log sql, 'DEBUG'

        return true if postgres_execute(sql).none?
      end

      sql = base_sql
      sql += device_data_filters(triggers)
      sql += ';'

      log sql, 'DEBUG'

      postgres_execute(sql).any? || custom_data_filters(triggers, custom_data)
    end

    def device_data_filters(triggers)
      sql = ""

      mandatory_triggers, non_mandatory_triggers = triggers.partition { |x| x['device_data_mandatory'] == 't' }

      mandatory_triggers.each do |trigger|
        sql += <<-SQL
          AND #{send("device_data_sql_#{trigger['device_data_matcher']}", trigger)}
        SQL
      end

      unless non_mandatory_triggers.empty?
        sql += <<-SQL
          AND (
        SQL

        non_mandatory_triggers.each_with_index do |trigger, index|
          sql += "OR " if index != 0

          sql += <<-SQL
            #{send("device_data_sql_#{trigger['device_data_matcher']}", trigger)}
          SQL
        end

        sql += <<-SQL
          )
        SQL
      end

      sql
    end

    def custom_data_filters(triggers, custom_data)
      return if (custom_data = valid_custom_data(custom_data)).empty?

      mandatory_triggers, non_mandatory_triggers = triggers.partition { |x| x['device_data_mandatory'] == 't' }

      mandatory_triggers_satisfied = mandatory_triggers.all? { |trigger| send("custom_data_#{trigger['device_data_matcher']}", trigger, custom_data) }

      return mandatory_triggers_satisfied if non_mandatory_triggers.empty?

      mandatory_triggers_satisfied && non_mandatory_triggers.any? { |trigger| send("custom_data_#{trigger['device_data_matcher']}", trigger, custom_data) }
    end

    def valid_custom_data(custom_data)
      JSON.parse(custom_data)
    rescue
      {}
    end

    def filter_survey_get_triggers(survey_id)
      sql = <<-SQL
        SELECT "triggers"."device_data_key", "triggers"."device_data_value", "triggers"."device_data_matcher", "triggers"."device_data_mandatory" FROM "triggers"
        WHERE "triggers"."survey_id" = '#{PG::Connection.escape(survey_id)}' AND "triggers"."device_data_matcher" IS NOT NULL
          AND ("triggers"."device_data_key" IS NOT NULL AND "triggers".device_data_key != '');
      SQL

      log sql, 'DEBUG'
      postgres_execute(sql)
    end

    def filter_client_key_trigger(client_key_required, client_key)
      return true unless client_key_required == 't'
      return false unless client_key

      sql = <<-SQL
        SELECT "devices"."id" FROM "devices" WHERE "devices"."client_key" = '#{PG::Connection.escape(client_key)}'
      SQL

      log sql, 'DEBUG'

      res = postgres_execute(sql)

      res.any?
    end
  end
end
