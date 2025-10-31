# frozen_string_literal: true
module Rack
  module DatabaseGetters
    # Find Accounts by identifier
    def get_account(identifier)
      sql = <<-SQL
        SELECT id, enabled, ips_to_block, domains_to_allow_for_redirection FROM accounts WHERE identifier = '#{PG::Connection.escape(identifier)}';
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql)
    end

    # Find Question by QuestionId
    def get_question(question_id)
      sql = <<-SQL
        SELECT questions.id, questions.position FROM questions WHERE questions.id = '#{PG::Connection.escape(question_id)}';
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql)
    end

    # Find Survey by QuestionId
    def get_survey(question_id)
      sql = <<-SQL
        SELECT surveys.id, surveys.name, surveys.poll_enabled, COUNT(questions.id) AS questions_size FROM surveys LEFT JOIN questions ON questions.survey_id = surveys.id WHERE questions.id = '#{PG::Connection.escape(question_id)}' GROUP BY surveys.id;
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql)
    end

    def get_survey_id_by_submission_udid(submission_udid)
      sql = <<-SQL
        SELECT survey_id FROM submissions WHERE submissions.udid = '#{PG::Connection.escape(submission_udid)}';
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql)[0]["survey_id"].to_i
    end

    def get_poll(question_id)
      sql = <<-SQL
        SELECT possible_answers.id, possible_answers.content, COUNT(answers.id)
        FROM possible_answers
        LEFT JOIN answers ON answers.possible_answer_id = possible_answers.id
        LEFT JOIN questions ON questions.id = possible_answers.question_id
        WHERE possible_answers.question_id = '#{PG::Connection.escape(question_id)}' AND questions.question_type IN (0,3)
        GROUP BY possible_answers.id, possible_answers.question_id, possible_answers.position
        ORDER BY possible_answers.position;
      SQL

      log sql, 'DEBUG'

      res = {}

      postgres_execute(sql).each do |row|
        res[row["id"].to_i] = { id: row["id"], content: row["content"], count: row["count"].to_i }
      end

      if res.any?
        res.values
      else
        res
      end
    end

    def get_device_id(udid)
      sql = <<-SQL
        SELECT devices.id FROM devices WHERE udid = '#{PG::Connection.escape(udid)}'
      SQL
      log sql, 'DEBUG'

      begin
        postgres_execute(sql).first['id']
      rescue
        nil
      end
    end

    def get_device_data(udid, identifier)
      sql = <<-SQL
        SELECT device_data.device_data FROM device_data LEFT JOIN accounts ON accounts.id = device_data.account_id LEFT JOIN devices ON devices.id = device_data.device_id
        WHERE accounts.identifier = '#{PG::Connection.escape(identifier)}' AND devices.udid = '#{PG::Connection.escape(udid)}'
      SQL

      begin
        JSON.parse postgres_execute(sql).first['device_data']
      rescue
        nil
      end
    end

    def get_question_contents(question_ids)
      postgres_execute(<<-SQL).map { |row| row['content'] }
        SELECT content
        FROM questions
        WHERE id IN (#{PG::Connection.escape(question_ids.join(','))})
      SQL
    end

    def get_possible_answer_contents(possible_answer_ids)
      postgres_execute(<<-SQL).map { |row| row['content'] }
        SELECT content
        FROM possible_answers
        WHERE id IN (#{PG::Connection.escape(possible_answer_ids.join(','))})
      SQL
    end
  end
end
