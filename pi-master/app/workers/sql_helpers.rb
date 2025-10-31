# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module SQLHelpers
  def response_sql
    <<-SQL
      CASE  WHEN questions.question_type = 1 THEN answers.text_answer
      ELSE possible_answers.content
      END response
    SQL
  end

  def channel_sql
    <<-SQL
      CASE
        WHEN submissions.device_type = 'email' THEN 'Email'
        WHEN submissions.device_type = 'native_mobile' THEN 'Native SDK'
        WHEN submissions.device_type = 'desktop' OR submissions.device_type = 'mobile' OR submissions.device_type = 'tablet' THEN 'Browser'
        ELSE 'Direct Submission/Link'
      END channel
    SQL
  end

  def browser_sql
    <<-SQL
      CASE
        WHEN submissions.user_agent LIKE '%Firefox/%' THEN 'Firefox'
        WHEN submissions.user_agent LIKE '%Edge/%' THEN 'Edge'
        WHEN submissions.user_agent LIKE '%Chrome/%' OR submissions.user_agent LIKE '%CriOS%' THEN 'Chrome'
        WHEN submissions.user_agent LIKE '%MSIE %' THEN 'Internet Explorer'
        WHEN submissions.user_agent LIKE '%MSIE+%' THEN 'Internet Explorer'
        WHEN submissions.user_agent LIKE '%Trident%' THEN 'Internet Explorer'
        WHEN submissions.user_agent LIKE '%iPhone%' THEN 'iPhone Safari'
        WHEN submissions.user_agent LIKE '%iPad%' THEN 'iPad Safari'
        WHEN submissions.user_agent LIKE '%Opera%' THEN 'Opera'
        WHEN submissions.user_agent LIKE '%BlackBerry%' AND submissions.user_agent LIKE '%Version/%' THEN 'BlackBerry WebKit'
        WHEN submissions.user_agent LIKE '%BlackBerry%' THEN 'BlackBerry'
        WHEN submissions.user_agent LIKE '%Android%' THEN 'Android'
        WHEN submissions.user_agent LIKE '%Safari%' THEN 'Safari'
        WHEN submissions.user_agent LIKE '%bot%' THEN 'Bot'
        WHEN submissions.user_agent LIKE '%http://%' THEN 'Bot'
        WHEN submissions.user_agent LIKE '%www.%' THEN 'Bot'
        WHEN submissions.user_agent LIKE '%Wget%' THEN 'Bot'
        WHEN submissions.user_agent LIKE '%curl%' THEN 'Bot'
        WHEN submissions.user_agent LIKE '%urllib%' THEN 'Bot'
        ELSE 'Unknown'
      END browser
    SQL
  end

  def browser_version_sql
    <<-SQL
      CASE
        WHEN s.browser = 'Firefox' THEN SUBSTRING(s.user_agent, POSITION('Firefox' IN s.user_agent) + 8, 100)
        WHEN s.browser = 'Safari' THEN SUBSTRING(s.user_agent, POSITION('Safari' IN s.user_agent) + 7, 100)
        WHEN s.browser = 'Chrome' THEN LEFT(SUBSTRING(s.user_agent, POSITION('Chrome' IN s.user_agent) + 7, 100),
                                            POSITION(' ' IN SUBSTRING(s.user_agent, POSITION('Chrome' IN s.user_agent) + 7, 100)))
        WHEN s.user_agent LIKE '%Trident%' THEN '11.0'
        WHEN s.browser = 'Internet Explorer' THEN SUBSTRING(s.user_agent, POSITION('MSIE' IN s.user_agent) + 5, 4)
        WHEN s.browser = 'Edge' THEN SUBSTRING(s.user_agent, POSITION('Edge' IN s.user_agent) + 5, 100)
        WHEN s.browser = 'iPhone Safari' THEN SUBSTRING(s.user_agent, POSITION('Safari' IN s.user_agent) + 7, 100)
        WHEN s.browser = 'iPad Safari' THEN SUBSTRING(s.user_agent, POSITION('Safari' IN s.user_agent) + 7, 100)
        ELSE 'Unknown'
      END browser_version
    SQL
  end

  def google_nlp_sql
    <<-SQL
      answers.sentiment->>'score' score,
      answers.sentiment->>'magnitude' magnitude,
      answers.entities->0->>'name' entity_1_name,
      answers.entities->0->>'type' entity_1_type,
      answers.entities->1->>'name' entity_2_name,
      answers.entities->1->>'type' entity_2_type,
      answers.entities->2->>'name' entity_3_name,
      answers.entities->2->>'type' entity_3_type,
      answers.entities->3->>'name' entity_4_name,
      answers.entities->3->>'type' entity_4_type
    SQL
  end

  def submissions_survey_locale_group_filter_sql
    <<-SQL
      submissions.survey_id IN (#{@survey_locale_group.survey_ids.join(', ')})
    SQL
  end

  def submissions_survey_filter_sql(market_ids)
    return true unless market_ids.present?

    <<-SQL
      submissions.survey_id IN (#{market_ids.join(', ')})
    SQL
  end

  # considering milliseconds as timestamp columns could be as precise as milliseconds. e.g. 2020-11-03 04:59:59.999999
  def submissions_date_filter_sql
    date_range_filter('submissions')
  end

  # considering milliseconds as timestamp columns could be as precise as milliseconds. e.g. 2020-11-03 04:59:59.999999
  def answers_date_filter_sql
    date_range_filter('answers')
  end

  def previous_surveys_sql
    <<-SQL
      (
        SELECT COUNT(surveys.id) FROM surveys
        LEFT JOIN submissions ON submissions.survey_id = surveys.id
        WHERE submissions.device_id = s.device_id AND submissions.created_at < s.submission_created_at
      ) previous_surveys
    SQL
  end

  def next_question_id_sql
    <<-SQL
      CASE  WHEN possible_answers.next_question_id IS NOT NULL THEN possible_answers.next_question_id
            WHEN questions.next_question_id IS NOT NULL THEN questions.next_question_id
            ELSE questions.free_text_next_question_id
      END next_question_id
    SQL
  end

  def base_question_join_sql
    <<-SQL
      LEFT JOIN questions AS base_question ON
        base_question.id = (
        SELECT
          id
        FROM
          questions
        WHERE
          questions.question_locale_group_id = question_locale_groups.id
        ORDER BY
          created_at
        LIMIT 1)
    SQL
  end

  def base_possible_answer_join_sql
    <<-SQL
      LEFT JOIN possible_answers AS base_possible_answer ON
        base_possible_answer.id = (
        SELECT
          id
        FROM
          possible_answers
        WHERE
          possible_answers.possible_answer_locale_group_id = possible_answer_locale_groups.id
        ORDER BY
          created_at
        LIMIT 1)
    SQL
  end

  private

  def date_range_filter(table_name)
    return true unless @date_range

    datetimes = [@date_range.first, @date_range.last]
    formatted_date_range = datetimes.map { |date_time| date_time.utc.strftime("%F %T.%6N") }

    <<-SQL
      #{table_name}.created_at BETWEEN '#{PG::Connection.escape(formatted_date_range.first)}'
                                 AND '#{PG::Connection.escape(formatted_date_range.last)}'
    SQL
  end
end
