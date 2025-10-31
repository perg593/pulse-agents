# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class PostAnswerWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Rack::Influx
  include Common

  def perform(pi_identifier, submission_udid, question_id, answer_id, text_answer, multiple_answer_ids)
    submission_id = Submission.find_with_retry_by!(udid: submission_udid).id

    return unless valid_question?(answer_id, question_id, pi_identifier, submission_id)
    return if already_answered?(question_id, submission_id)
    return if optional_question_with_no_answer?(question_id, answer_id, text_answer, multiple_answer_ids)
    answer = save_answer(pi_identifier, answer_id, question_id, text_answer, multiple_answer_ids, submission_id)

    has_reached_goal = goal_reached?(submission_id)

    if has_reached_goal.any?
      has_reached_goal = has_reached_goal.first
      update_status_to_completed(has_reached_goal['id'])
      SurveyMailer.send_completion_email(has_reached_goal['id']).deliver_now
    end

    answer
  ensure
    postgres_disconnect!
  end

  private

  def update_status_to_completed(id)
    log 'Survey has reached goal, switching status to completed'

    Survey.find(id).update(status: Survey.statuses["complete"])
  end

  def goal_reached?(submission_id)
    # Reached goal ?
    sql = <<-SQL
      SELECT "surveys"."id"
      FROM "surveys"
      INNER JOIN "survey_stats" ON "surveys"."id" = "survey_stats"."survey_id"
      INNER JOIN "submissions" ON "submissions"."survey_id" = "surveys"."id"
      WHERE "submissions"."id" = #{PG::Connection.escape(submission_id.to_s).to_i} AND "survey_stats"."answers_count" >= "surveys"."goal"
    SQL

    log sql, 'DEBUG'
    postgres_execute(sql)
  end

  def insert_answer_with_answer_id(question_id, answer_id, submission_id)
    <<-SQL
      INSERT INTO "answers" ("question_id", "question_type", "possible_answer_id", "submission_id", "created_at", "updated_at")
      VALUES (#{PG::Connection.escape(question_id.to_s).to_i},
              #{Question.question_types[Question.find(question_id).question_type]}, /* This will be simplified in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2379 */
              #{PG::Connection.escape(answer_id.to_s).to_i},
              #{PG::Connection.escape(submission_id.to_s).to_i}, (
              now() at time zone 'utc'),
              (now() at time zone 'utc')) RETURNING id;
    SQL
  end

  def insert_answer_with_text_answer(question_id, text_answer, submission_id)
    <<-SQL
        INSERT INTO "answers" ("question_id", "question_type", "text_answer", "submission_id", "created_at", "updated_at")
        VALUES (#{PG::Connection.escape(question_id.to_s).to_i},
                #{Question.question_types[:free_text_question]},
                '#{PG::Connection.escape(text_answer.to_s)}',
                #{PG::Connection.escape(submission_id.to_s).to_i},
                (now() at time zone 'utc'),
                (now() at time zone 'utc')) RETURNING id;
    SQL
  end

  def insert_answers_for_multiple_answer_ids(question_id, multiple_answer_ids, submission_id)
    answer_ids = multiple_answer_ids.split(',').uniq
    sql = <<-SQL
          INSERT INTO "answers" ("question_id", "question_type", "possible_answer_id", "submission_id", "created_at", "updated_at") VALUES
    SQL
    answer_ids.each do |id|
      sql += <<-SQL
          (#{PG::Connection.escape(question_id.to_s).to_i},
          #{Question.question_types[:multiple_choices_question]},
          #{PG::Connection.escape(id.to_s).to_i},
          #{PG::Connection.escape(submission_id.to_s).to_i},
          (now() at time zone 'utc'),
          (now() at time zone 'utc')) #{',' unless id == answer_ids.last}
      SQL
      next unless id == answer_ids.last
      sql += <<-SQL
            RETURNING id;
      SQL
    end

    sql
  end

  def save_answer(identifier, possible_answer_id, question_id, text_answer, multiple_answer_ids, submission_id)
    text_answer = mask_personal_data(identifier, text_answer) if text_answer.present?

    sql = if possible_answer_id
      insert_answer_with_answer_id(question_id, possible_answer_id, submission_id)
    elsif text_answer
      insert_answer_with_text_answer(question_id, text_answer, submission_id)
    elsif multiple_answer_ids
      insert_answers_for_multiple_answer_ids(question_id, multiple_answer_ids, submission_id)
    else
      raise 'No answer value'
    end

    log sql, 'DEBUG'

    begin
      answer_ids = postgres_execute(sql).map { |a| a['id'].to_i }
    rescue StandardError => e
      report_to_rollbar("Duplicate Answer insertion attempt", sql: sql, full_message: e.full_message)
      return
    end

    answer_ids.each { |answer_id| KeywordMatchNotificationWorker.perform_async(answer_id) }

    res = increment_answers_count_submission(submission_id)
    submission_answers_count = res.first['answers_count'].to_i

    # We only increment surveys#answers_count one time per submission
    increment_answers_count_survey(submission_id) if submission_answers_count == 1

    # log the count of saved answers in influxDB
    log_answer_count_influxdb(answer_ids.count)

    answer_ids
  end

  def increment_answers_count_submission(submission_id)
    sql = <<-SQL
      UPDATE "submissions" SET
      "answers_count"=(SELECT "submissions"."answers_count" FROM "submissions"
                        WHERE "submissions"."id"=#{PG::Connection.escape(submission_id.to_s).to_i} LIMIT 1)+1
                        WHERE "submissions"."id"=#{PG::Connection.escape(submission_id.to_s).to_i};
    SQL

    log sql, 'DEBUG'
    postgres_execute(sql)

    sql = <<-SQL
      SELECT "submissions"."answers_count" FROM "submissions" WHERE "submissions"."id"=#{PG::Connection.escape(submission_id.to_s).to_i};
    SQL

    log sql, 'DEBUG'
    postgres_execute(sql)
  end

  def increment_answers_count_survey(submission_id)
    sql = <<-SQL
      UPDATE  survey_stats
      SET     answers_count =
          (SELECT survey_stats.answers_count
          FROM survey_stats
          LEFT JOIN surveys ON surveys.id = survey_stats.survey_id
          LEFT JOIN submissions ON submissions.survey_id = surveys.id
          WHERE submissions.id = #{PG::Connection.escape(submission_id.to_s).to_i}) + 1
      WHERE   survey_stats.survey_id IN
          (SELECT surveys.id
          FROM surveys
          LEFT JOIN submissions ON submissions.survey_id = surveys.id
          WHERE submissions.id = #{PG::Connection.escape(submission_id.to_s).to_i})
    SQL

    log sql, 'DEBUG'
    postgres_execute(sql)
  end

  def optional_question_with_no_answer?(question_id, answer_id, text_answer, multiple_answer_ids)
    answer_exist = answer_id.present? || text_answer.present? || multiple_answer_ids.present?
    return false if answer_exist

    optional = postgres_execute(<<-SQL)
      SELECT optional FROM questions WHERE id = #{PG::Connection.escape(question_id.to_s).to_i}
    SQL
    return false if optional == 'f'

    log 'Optional question with no answer.'
    postgres_disconnect!
    true
  end

  def already_answered?(question_id, submission_id)
    # Check if for this submission, we already have an answer to this question
    sql = <<-SQL
      SELECT COUNT(answers.id)
      FROM answers
      WHERE answers.submission_id = #{PG::Connection.escape(submission_id.to_s).to_i} AND question_id = #{PG::Connection.escape(question_id.to_s).to_i};
    SQL

    log sql, 'DEBUG'

    count = nil
    postgres_execute(sql).each_row do |row|
      count = row.first.to_i
    end

    if count.zero?
      false
    else
      log 'Answer already existing.'
      postgres_disconnect!
      true
    end
  end

  def valid_question?(answer_id, question_id, pi_identifier, submission_id)
    sql = count_sql(answer_id, question_id, pi_identifier, submission_id)

    log sql, 'DEBUG'

    count = nil

    postgres_execute(sql).each_row do |row|
      count = row.first.to_i
    end

    if count == 1
      true
    else
      log 'Inconsistent data.'
      postgres_disconnect!
      false
    end
  end

  def count_sql(answer_id, question_id, pi_identifier, submission_id)
    if answer_id
      sql_with_answer_id(answer_id, question_id, pi_identifier, submission_id)
    else
      sql_without_answer_id(question_id, pi_identifier, submission_id)
    end
  end

  def sql_with_answer_id(answer_id, question_id, pi_identifier, submission_id)
    # Check that we have ONE possible answer such as:
    #  - a possible answer with this id exists
    #  - the possible answer is linked to the question_id
    #  - within a question, from a survey, belonging to account with the passed pi identifier
    #  - and that the submission is related to the survey for which the question's possible answer belongs to.
    #  - of a question of type 'single choice question' or 'slider question'
    <<-SQL
      SELECT COUNT(possible_answers.id)
      FROM possible_answers
        INNER JOIN questions ON questions.id = possible_answers.question_id
        INNER JOIN surveys ON surveys.id = questions.survey_id
        INNER JOIN accounts ON accounts.id = surveys.account_id
        INNER JOIN submissions ON submissions.survey_id = surveys.id
        WHERE
          possible_answers.id = #{PG::Connection.escape(answer_id.to_s).to_i}
          AND questions.question_type IN (0, 4) /* single choice or slider */
          AND questions.id = #{PG::Connection.escape(question_id.to_s).to_i}
          AND accounts.identifier = '#{PG::Connection.escape(pi_identifier.to_s)}'
          AND submissions.id = #{PG::Connection.escape(submission_id.to_s).to_i};
    SQL
  end

  def sql_without_answer_id(question_id, pi_identifier, submission_id)
    # Check that we have ONE question such as:
    #  - from a survey, belonging to account with the passed pi identifier
    #  - and that the submission is related to the survey
    #  - of a question of type 'free text question'
    <<-SQL
      SELECT COUNT(questions.id)
      FROM questions
        INNER JOIN surveys ON surveys.id = questions.survey_id
        INNER JOIN accounts ON accounts.id = surveys.account_id
        INNER JOIN submissions ON submissions.survey_id = surveys.id
        WHERE
          questions.id = #{PG::Connection.escape(question_id.to_s).to_i}
          AND (questions.question_type = 1 OR questions.question_type = 2 OR questions.question_type = 3)
          AND accounts.identifier = '#{PG::Connection.escape(pi_identifier.to_s)}'
          AND submissions.id = #{PG::Connection.escape(submission_id.to_s).to_i};
    SQL
  end

  def mask_personal_data(identifier, text)
    setting = personal_data_setting(identifier)

    return text if setting['masking_enabled'] == 'f'

    # Social Security Number -> https://stackoverflow.com/a/7067903/12065544
    ssn_regex   = /(^|\s)\d{3}-\d{2}-\d{4}($|\s)/
    # UK National Insurance -> https://stackoverflow.com/a/17779536/12065544
    ni_regex    = /(^|\s)(?!BG)(?!GB)(?!NK)(?!KN)(?!TN)(?!NT)(?!ZZ)(?:[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z])(?:\s*\d\s*){6}([A-D]|\s)/i
    # https://stackoverflow.com/a/17767762/12065544
    phone_regex = /(^|\s|\+)\d{2}[\s\d-]{6,}($|\s)/
    # https://stackoverflow.com/a/42408099/12065544
    email_regex = /(^|\s)([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)($|\s)/

    masking_text = '*****'

    text = text.dup
    text.gsub!(ssn_regex, masking_text)
    text.gsub!(ni_regex, masking_text)
    text.gsub!(phone_regex, masking_text) if setting['phone_number_masked'] == 't'
    text.gsub!(email_regex, masking_text) if setting['email_masked'] == 't'
    text
  end

  def personal_data_setting(identifier)
    sql = <<-SQL
      SELECT masking_enabled, phone_number_masked, email_masked
      FROM personal_data_settings
      JOIN accounts ON personal_data_settings.account_id = accounts.id
      WHERE accounts.identifier = '#{PG::Connection.escape(identifier.to_s)}'
    SQL

    postgres_execute(sql).first
  end

  # rubocop:disable Lint/RescueException
  def log_answer_count_influxdb(answer_count)
    influxdb_connect!

    begin
      @influx_client.influxdb.write_points({ series: 'pi_answer_count', values: { count: answer_count } })
    rescue Exception => e # we want to catch everything
      log " !!! Error writing to InfluxDB(pi_answer_count): #{e.inspect}"
    end
  end
end
