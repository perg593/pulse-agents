# frozen_string_literal: true
module Rack
  module DatabasePresentResults
    def get_survey_results(survey_id)
      sql = <<-SQL
        SELECT COUNT(answers.id) AS "answers_count", questions.id AS "question_id",
        questions.position AS "question_position",
        questions.content AS "question_content",
        possible_answers.id AS "possible_answer_id",
        possible_answers.position AS "possible_answer_position",
        possible_answers.content AS "possible_answer_content"
        FROM surveys
        LEFT JOIN questions ON questions.survey_id = surveys.id
        INNER JOIN possible_answers ON possible_answers.question_id = questions.id
        LEFT JOIN answers ON answers.possible_answer_id = possible_answers.id
        WHERE surveys.id = #{survey_id}
        GROUP BY questions.id, possible_answers.id
        ORDER BY questions.position, possible_answers.position
      SQL

      postgres_execute(sql)
    end

    def get_thank_you_and_poll(submission_udid)
      sql = <<-SQL
        SELECT surveys.poll_enabled, surveys.thank_you, answers.question_id, questions.content, questions.question_type
        FROM submissions
        LEFT JOIN surveys ON surveys.id = submissions.survey_id
        LEFT JOIN answers ON answers.submission_id = submissions.id
        LEFT JOIN questions ON questions.id = answers.question_id
        WHERE submissions.udid = '#{PG::Connection.escape(submission_udid)}'
            AND answers.id =
            (
                SELECT MAX(answers.id)
                FROM answers
                WHERE answers.submission_id = submissions.id
            )
      SQL

      res = postgres_execute(sql)
      res.first if res.any?
    end

    def get_answers_via_checkbox(submission_udid, question_id)
      sql = <<-SQL
        SELECT answers.id
        FROM answers
        LEFT JOIN submissions ON answers.submission_id = submissions.id
        WHERE submissions.udid = '#{PG::Connection.escape(submission_udid)}' AND answers.question_id = #{PG::Connection.escape(question_id)}
      SQL

      res = postgres_execute(sql)

      if res.any?
        res.map { |h| h['id'] }
      else
        []
      end
    end
  end
end
