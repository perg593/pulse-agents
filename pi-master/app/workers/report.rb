# frozen_string_literal: true

require 'csv'

# rubocop:disable Metrics/AbcSize, Metrics/ModuleLength
module Report
  include Numerable
  include SQLHelpers

  LIMIT_FOR_INDIVIDUAL_XLSX = 25000 # https://gitlab.ekohe.com/ekohe/pi/issues/953
  DATE_FORMAT = '%m/%d/%Y'

  def survey_metadata
    generate_sheet 'Survey metadata' do |sheet|
      sheet.add_row [survey_metadata_header] + ([nil] * 9), style: @section_title
      sheet.add_row [survey_metadata_name, @reportee.name], style: @normal_cell
      sheet.add_row ['Author:', @reportee.updated_by_name], style: @normal_cell
      sheet.add_row ['Reporting Dates:', human_date_range], style: @normal_cell
      sheet.add_row ['Report Generated:', Time.current.strftime(DATE_FORMAT)], style: @normal_cell
      sheet.column_widths 20, 20
    end
  end

  def individual_rows
    generate_sheet 'Individual rows' do |sheet|
      sheet.add_row answer_mapper.keys, style: @tr_cell
      answers_rows.each { |answer| sheet.add_row(answer_mapper(answer: answer).values, style: individual_row_style) }
    end
  end

  def custom_content_link_clicks_sheet
    generate_sheet "Custom Content Clicks" do |sheet|
      sheet.add_row custom_content_link_mapper.keys, style: @tr_cell

      if custom_content_link_click_rows.present?
        custom_content_link_click_rows.each { |answer| sheet.add_row(custom_content_link_mapper(answer: answer).values, style: individual_row_style) }
      end
    end
  end

  def add_custom_content_link_click_rows(sheet, question)
    sheet.add_row [nil] # padding
    sheet.add_row [nil, nil, nil, "Clicks", "Share"], style: @tr_cell

    total_clicks_for_question = question.custom_content_links.sum { |custom_content_link| custom_content_link.click_count(filters: @filters) }

    sheet.add_row([question.content, nil, nil, total_clicks_for_question])

    question.custom_content_links.order(:link_text).each do |custom_content_link|
      click_count = custom_content_link.click_count(filters: @filters)
      click_share = percent_of(click_count, total_clicks_for_question)

      sheet.add_row(["  #{custom_content_link.link_text}", custom_content_link.link_url, nil, click_count, click_share],
                    style: [@normal_cell, nil, nil, @td_cell, @td_cell])
    end
  end

  def questions
    generate_sheet 'Questions' do |sheet|
      sheet.add_row ['RESPONSE SUMMARIES'] + ([nil] * 9), style: @section_title
      sheet.add_row [nil, nil, nil, 'Responses', 'Share'], style: @tr_cell

      reportee_questions.each do |question|
        question_answer_count = if localized_report?
          localized_question_answer_count(question)
        else
          question.answers_count(:group_submission_id, filters: @filters)
        end

        sheet.add_row [question.content, nil, nil, question_answer_count, nil], style: [@normal_cell, nil, nil, @td_cell, nil]

        sheet.add_row([nil]) && next if question.question_type == "free_text_question"

        question.possible_answers.sort_by_position.each do |possible_answer|
          answer_count = if localized_report?
            localized_possible_answer_answer_count(possible_answer)
          else
            possible_answer.answers_count(filters: @filters)
          end

          answer_rate = percent_of(answer_count, question_answer_count)
          sheet.add_row ["  #{possible_answer.content}", nil, nil, answer_count, answer_rate], style: [@normal_cell, nil, nil, @td_cell, @td_cell]
        end

        if question.custom_content_question?
          add_custom_content_link_click_rows(sheet, question)
        end

        sheet.add_row([nil]) # Add blank line between each question
      end
      sheet.column_widths(*([15] * 5))
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
  # report generation gets complicated sometimes
  def devices
    generate_sheet 'Devices' do |sheet|
      device_headers = (device_mapper.keys + device_questions_headers).flatten
      sheet.add_row device_headers, style: @tr_cell

      questions = postgres_execute(devices_questions_sql, readonly: true)
      questions_per_survey = questions.group_by { |row| row['survey_id'] } if localized_report?

      devices_per_submission = postgres_execute(devices_sql, readonly: true).group_by { |row| row['submission_id'] }
      devices_per_submission.each_value do |devices|
        row = device_mapper(device: devices.first).values

        questions = questions_per_survey[devices.first['survey_id']] if localized_report?
        questions.each do |question|
          row += [question['question_content'], question['question_id']]

          answer = devices.find { |device| device['question_id'] == question['question_id'] }
          row +=
            if question['question_type'].to_i == Question.question_types[:free_text_question]
              answer.present? ? [answer['possible_answer_id'], answer['response'], answer["translated_response"], answer['tags']] : ['', '', '', '']
            else
              answer.present? ? [answer['possible_answer_id'], answer['response']] : ['', '']
            end

          next unless localized_report?
          row += [question['base_question_content'], question['question_group_id']]
          row += answer.present? ? [answer['base_response_content'], answer['response_group_id']] : ['', '']
        end
        sheet.add_row row
      end
    end
  end

  def include_link_clicks?
    @include_link_clicks ||= @account.custom_content_link_click_enabled &&
                             Question.where(survey_id: reportee_surveys.pluck(:id)).joins(:custom_content_links).exists?
  end

  def link_clicks_per_date
    sql = <<-SQL
      SELECT
        COALESCE(SUM(1), 0) AS link_click_count,
        DATE(custom_content_link_clicks.created_at) AS created_date
      FROM custom_content_link_clicks
      LEFT JOIN submissions ON submissions.id = custom_content_link_clicks.submission_id
      WHERE submissions.survey_id IN (#{reportee_surveys.pluck(:id).join(', ')})
        AND #{submissions_date_filter_sql}
        #{submissions_filters}
      GROUP BY DATE(custom_content_link_clicks.created_at)
      ORDER BY DATE(custom_content_link_clicks.created_at) DESC
    SQL

    @link_clicks_per_date ||= postgres_execute(sql, readonly: true)
  end

  def link_clicks_total
    @link_clicks_total ||= (link_clicks_per_date.sum { |link_clicks_row| link_clicks_row['link_click_count'].to_i }) || 0
  end

  def link_clicks_on_date(date)
    clicks_on_current_date = link_clicks_per_date.detect { |link_clicks_row| link_clicks_row['created_date'] == date }
    clicks_on_current_date.try(:[], "link_click_count").to_i
  end

  def aggregate_results_by_day_headers
    headers = ['Date', 'Impressions', 'Submissions', 'Submission Rate']
    headers << "Link Clicks" if include_link_clicks?
    headers
  end

  def aggregate_results_by_day(date_format: DATE_FORMAT)
    generate_sheet 'Aggregate results by day' do |sheet|
      sheet.add_row ['SUMMARY STATS BY DAY'] + ([nil] * 9), style: @section_title

      sheet.add_row aggregate_results_by_day_headers, style: @tr_cell

      @survey_stats_per_day.each do |row|
        row_cells = [
          row['created_date'].to_date.strftime(date_format),
          row['blended_impression_count'],
          row['submission_count'],
          "#{row['submission_rate'].to_i}%"
        ]

        row_cells << link_clicks_on_date(row["created_date"]) if include_link_clicks?

        sheet.add_row row_cells, style: @td_cell
      end

      totals_cells = [
        'TOTAL',
        @blended_impression_size,
        @submission_size,
        @submission_rate
      ]

      totals_cells << link_clicks_total if include_link_clicks?

      sheet.add_row totals_cells, style: @td_cell, b: true

      sheet.column_widths 20, 15, 15, 20
    end
  end

  def survey_stats_per_day_sql
    <<-SQL
      SELECT
        DATE(submissions.created_at) AS created_date,
        COALESCE(SUM(1), 0) AS impression_count,
        COALESCE(SUM(CASE WHEN viewed_at IS NULL THEN 0 ELSE 1 END), 0) AS viewed_impression_count,
        COALESCE(SUM(CASE WHEN answers_count = 0 THEN 0 ELSE 1 END), 0) AS submission_count
      FROM submissions
      WHERE submissions.survey_id IN (#{reportee_surveys.pluck(:id).join(', ')})
        AND #{submissions_date_filter_sql}
        #{submissions_filters}
      GROUP BY DATE(submissions.created_at)
      ORDER BY DATE(submissions.created_at) DESC
    SQL
  end

  def generate_sheet(sheet_name, &generation)
    start_time = Time.current
    @wb.add_worksheet(name: sheet_name, &generation)
    end_time = Time.current
    tagged_logger.info "#{sheet_name} generated in #{(end_time - start_time).to_i} seconds"
  end

  def survey_metadata_header
    case @reportee
    when SurveyLocaleGroup
      'PULSE INSIGHTS SURVEY GROUP REPORTING'
    when Survey
      'PULSE INSIGHTS SURVEY REPORTING'
    end
  end

  def survey_metadata_name
    case @reportee
    when SurveyLocaleGroup
      'Survey Group Name:'
    when Survey
      'Survey Name:'
    end
  end

  # TODO: populate up to the number of the columns
  def individual_row_style
    [@td_cell, @td_cell, @normal_cell, @normal_cell, @td_cell, @td_cell, @td_cell, @td_cell, @normal_cell, @td_cell, @td_cell, @td_cell, @td_cell, @td_cell]
  end

  def upload_csv_file
    return 'www.placeholder_for_tests.ca/csv' unless %w(production staging develop).include? Rails.env

    obj = s3_bucket.object(File.basename(individual_rows_filepath))
    obj.upload_file individual_rows_filepath, content_type: 'application/ms-excel'
    obj.presigned_url(:get, expires_in: 7 * 86400) # expires in 7 days
  end

  def generate_csv
    individual_rows_csv
  end

  def individual_rows_csv
    start_time = Time.current
    CSV.open(individual_rows_filepath, 'wb') do |csv|
      csv << answer_mapper.keys
      answers_rows.each { |answer| csv << answer_mapper(answer: answer).values }
    end
    end_time = Time.current
    tagged_logger.info "Individual rows CSV generated in #{(end_time - start_time).to_i} seconds"
  end

  def individual_rows_filepath
    "tmp/pulse_insights_report_individual_rows_#{@reportee.name.parameterize}_#{@today}.csv"
  end

  def device_questions_headers
    reportee_questions.map do |question|
      header = %w(Question QuestionID ResponseID Response)
      header += ['Translated Response', 'Tags'] if question.question_type == "free_text_question"
      header += ['Question Base', 'Question Group ID', 'Response Base', 'Response Group ID'] if localized_report?
      header
    end
  end

  def device_mapper(device: {})
    map = {
      "DeviceUDID"             => device['udid'],
      "Device Type"            => device['device_type'],
      "Client Key"             => device['client_key'],
      "Date"                   => device['date'],
      "Time"                   => device['time'],
      "Survey Group Name"      => device['survey_locale_group_name'],
      "Survey Group ID"        => device['survey_locale_group_id'],
      "Survey Name"            => device['survey_name'],
      "SurveyID"               => device['survey_id'],
      "Pageview Count"         => device['pageview_count'],
      "Visit Count"            => device['visit_count'],
      "Completion URL"         => device['url'],
      "View Name"              => device['view_name'],
      "IP Address"             => device['ip_address'],
      "Event"                  => device['pseudo_event'],
      "Context Data"           => device['custom_data'],
      "Device Data"            => device['device_data'],
      "Sentiment Score"        => device['score'],
      "Sentiment Magnitude"    => device['magnitude'],
      "Entity 1 name"          => device['entity_1_name'],
      "Entity 1 type"          => device['entity_1_type'],
      "Entity 2 name"          => device['entity_2_name'],
      "Entity 2 type"          => device['entity_2_type'],
      "Entity 3 name"          => device['entity_3_name'],
      "Entity 3 type"          => device['entity_3_type'],
      "Entity 4 name"          => device['entity_4_name'],
      "Entity 4 type"          => device['entity_4_type'],
      "OS"                     => device['os'],
      "Browser"                => device['browser'],
      "Browser Version"        => device['browser_version'],
      "Channel"                => device['channel']
    }
    map.delete('IP Address') unless @include_ip_column
    ['Survey Group Name', 'Survey Group ID'].each { |key| map.delete(key) } unless localized_report?
    map
  end

  def devices_questions_sql
    <<-SQL
        SELECT
          questions.id question_id,
          questions.survey_id survey_id,
          questions.content question_content,
          questions.question_type question_type,
          question_locale_groups.id question_group_id,
          base_question.content base_question_content
        FROM questions
        LEFT JOIN locale_groups AS question_locale_groups ON question_locale_groups.type = 'QuestionLocaleGroup' AND question_locale_groups.id = questions.question_locale_group_id
        #{base_question_join_sql}
        WHERE questions.survey_id IN (#{reportee_surveys.pluck(:id).join(',')})
        ORDER BY questions.position
    SQL
  end

  def devices_sql
    <<-SQL
      SELECT  *,
        substring(s.user_agent from '\\((.*?)\\)') os,
        #{browser_version_sql}
        FROM (
          SELECT
            submissions.view_name,
            submissions.ip_address,
            submissions.pseudo_event,
            submissions.id submission_id,
            submissions.device_type,
            devices.client_key,
            to_char(submissions.created_at, 'MM/DD/YYYY') AS date,
            to_char(submissions.created_at, 'HH24:MI:SS') AS time,
            survey_locale_groups.id survey_locale_group_id,
            survey_locale_groups.name survey_locale_group_name,
            possible_answer_locale_groups.id response_group_id,
            base_possible_answer.content base_response_content,
            surveys.id survey_id,
            surveys.name survey_name,
            submissions.pageview_count,
            submissions.visit_count,
            submissions.url,
            submissions.custom_data::text,
            device_data.device_data,
            submissions.user_agent,
            submissions.device_id,
            devices.udid,
            questions.content question_content,
            questions.id question_id,
            answers.id response_id,
            answers.translated_answer AS translated_response,
            possible_answers.id possible_answer_id,
            string_agg(tags.name, ', ') tags,
            #{response_sql},
            #{channel_sql},
            #{browser_sql},
            #{google_nlp_sql}
          FROM submissions
          LEFT JOIN devices ON devices.id = submissions.device_id
          LEFT JOIN answers ON answers.submission_id = submissions.id
          LEFT JOIN surveys ON surveys.id = submissions.survey_id
          LEFT JOIN locale_groups AS survey_locale_groups ON survey_locale_groups.type = 'SurveyLocaleGroup' AND survey_locale_groups.id = surveys.survey_locale_group_id
          LEFT JOIN questions ON questions.id = answers.question_id
          LEFT JOIN possible_answers ON answers.possible_answer_id = possible_answers.id
          LEFT JOIN locale_groups AS possible_answer_locale_groups ON possible_answer_locale_groups.type = 'PossibleAnswerLocaleGroup' AND possible_answer_locale_groups.id = possible_answers.possible_answer_locale_group_id
          LEFT JOIN device_data ON device_data.device_id = devices.id AND device_data.account_id = surveys.account_id
          LEFT JOIN applied_tags ON answers.id = applied_tags.answer_id
          LEFT JOIN tags on tags.id = applied_tags.tag_id
          #{base_possible_answer_join_sql}
          WHERE submissions.survey_id IN (#{reportee_surveys.pluck(:id).join(', ')})
            AND submissions.answers_count > 0
            AND #{submissions_date_filter_sql}
            #{submissions_filters}
          GROUP BY base_possible_answer.content, survey_locale_groups.id, survey_locale_groups.name, surveys.id, devices.id, questions.id, answers.id, possible_answers.id, possible_answer_locale_groups.id, submissions.id, device_data.id
          ORDER BY submissions.created_at ASC
        ) s;
    SQL
  end

  def answers_sql
    <<-SQL
      SELECT *,
        (select question_locale_group_id from questions where id = s.next_question_id) next_question_locale_group_id,
        substring(s.user_agent from '\\((.*?)\\)') os,
        #{previous_surveys_sql},
        #{browser_version_sql}
      FROM (
        SELECT
          submissions.view_name view_name,
          devices.udid || '_' || CAST(submissions.id AS TEXT) device_udid_submission_id,
          submissions.created_at submission_created_at,
          to_char(answers.created_at, 'MM/DD/YYYY') AS date,
          to_char(answers.created_at, 'HH24:MI:SS') AS time,
          string_agg(tags.name, ', ') tags,
          surveys.language_code,
          surveys.locale_code,
          survey_locale_groups.name survey_group_name,
          survey_locale_groups.id survey_group_id,
          surveys.name survey_name,
          questions.survey_id survey_id,
          questions.id question_id,
          questions.content question,
          question_locale_groups.id question_group_id,
          question_locale_groups.name question_group_name,
          base_question.content base_question_content,
          possible_answer_locale_groups.id response_group_id,
          possible_answer_locale_groups.name response_group_name,
          answers.possible_answer_id response_id,
          base_possible_answer.content base_possible_answer_content,
          submissions.id submission_id,
          submissions.pageview_count,
          submissions.visit_count,
          submissions.ip_address,
          submissions.device_type,
          devices.id device_id,
          devices.udid,
          devices.client_key,
          submissions.url,
          submissions.pseudo_event,
          submissions.custom_data::text,
          device_data.device_data,
          submissions.user_agent,
          answers.translated_answer AS translated_response,
          #{next_question_id_sql},
          #{response_sql},
          #{channel_sql},
          #{browser_sql},
          #{google_nlp_sql}
          FROM answers
          LEFT JOIN submissions ON submissions.id = answers.submission_id
          LEFT JOIN surveys ON surveys.id = submissions.survey_id
          LEFT JOIN locale_groups AS survey_locale_groups ON survey_locale_groups.type = 'SurveyLocaleGroup' AND survey_locale_groups.id = surveys.survey_locale_group_id
          LEFT JOIN questions ON questions.id = answers.question_id
          LEFT JOIN locale_groups AS question_locale_groups ON question_locale_groups.type = 'QuestionLocaleGroup' AND question_locale_groups.id = questions.question_locale_group_id
          LEFT JOIN possible_answers ON possible_answers.id = answers.possible_answer_id
          LEFT JOIN locale_groups AS possible_answer_locale_groups ON possible_answer_locale_groups.type = 'PossibleAnswerLocaleGroup' AND possible_answer_locale_groups.id = possible_answers.possible_answer_locale_group_id
          LEFT JOIN applied_tags ON applied_tags.answer_id = answers.id
          LEFT JOIN tags ON tags.id = applied_tags.tag_id
          LEFT JOIN devices ON submissions.device_id = devices.id
          LEFT JOIN device_data ON device_data.device_id = devices.id AND device_data.account_id = surveys.account_id
          #{base_question_join_sql}
          #{base_possible_answer_join_sql}
          WHERE surveys.id IN (#{reportee_surveys.pluck(:id).join(', ')})
            AND #{answers_date_filter_sql}
            #{submissions_filters}
          GROUP BY base_question.content, base_possible_answer.content, survey_locale_groups.name, survey_locale_groups.id, question_locale_groups.id, possible_answer_locale_groups.id, surveys.id, answers.id, submissions.id, questions.id, possible_answers.id, devices.id, device_data.id
          ORDER BY answers.created_at DESC) s
    SQL
  end

  def custom_content_link_click_sql
    <<-SQL
      SELECT *,
        substring(s.user_agent from '\\((.*?)\\)') os,
        #{previous_surveys_sql},
        #{browser_version_sql}
      FROM (
        SELECT
          submissions.view_name,
          submissions.created_at submission_created_at,
          to_char(custom_content_link_clicks.created_at, 'MM/DD/YYYY') AS date,
          to_char(custom_content_link_clicks.created_at, 'HH24:MI:SS') AS time,
          surveys.language_code,
          surveys.locale_code,
          survey_locale_groups.name survey_group_name,
          survey_locale_groups.id survey_group_id,
          surveys.name survey_name,
          questions.survey_id survey_id,
          questions.id question_id,
          questions.content question,
          question_locale_groups.id question_group_id,
          question_locale_groups.name question_group_name,
          base_question.content base_question_content,
          submissions.id submission_id,
          submissions.pageview_count,
          submissions.visit_count,
          submissions.ip_address,
          submissions.device_type,
          devices.id device_id,
          devices.udid,
          submissions.url,
          submissions.pseudo_event,
          device_data.device_data,
          submissions.user_agent,
          #{channel_sql},
          #{browser_sql},

          custom_content_link_clicks.custom_content_link_id,
          custom_content_link_clicks.client_key,
          custom_content_link_clicks.custom_data::text,
          custom_content_links.link_text,
          custom_content_links.link_url

          FROM custom_content_link_clicks
          LEFT JOIN custom_content_links ON custom_content_links.id = custom_content_link_clicks.custom_content_link_id

          LEFT JOIN submissions ON submissions.id = custom_content_link_clicks.submission_id
          LEFT JOIN surveys ON surveys.id = submissions.survey_id
          LEFT JOIN locale_groups AS survey_locale_groups ON survey_locale_groups.type = 'SurveyLocaleGroup' AND survey_locale_groups.id = surveys.survey_locale_group_id
          LEFT JOIN questions ON questions.id = custom_content_links.question_id
          LEFT JOIN locale_groups AS question_locale_groups ON question_locale_groups.type = 'QuestionLocaleGroup' AND question_locale_groups.id = questions.question_locale_group_id
          LEFT JOIN devices ON submissions.device_id = devices.id
          LEFT JOIN device_data ON device_data.device_id = devices.id AND device_data.account_id = surveys.account_id
          #{base_question_join_sql}
          WHERE custom_content_links.archived_at IS NULL
            AND surveys.id IN (#{reportee_surveys.pluck(:id).join(', ')})
            AND #{submissions_date_filter_sql}
            #{submissions_filters}
          GROUP BY base_question.content, survey_locale_groups.name, survey_locale_groups.id, custom_content_links.link_text, custom_content_links.link_url, question_locale_groups.id, surveys.id, custom_content_link_clicks.id, submissions.id, questions.id, devices.id, device_data.id
          ORDER BY custom_content_link_clicks.created_at DESC) s
    SQL
  end

  def submissions_filters
    <<-SQL
      AND #{Submission.submissions_device_filter_sql(@filters[:device_types])}
      AND #{Submission.submissions_completion_url_filter_sql(@filters[:completion_urls])}
      AND #{Submission.submissions_pageview_count_filter_sql(@filters[:pageview_count])}
      AND #{Submission.submissions_visit_count_filter_sql(@filters[:visit_count])}
      AND #{Submission.submissions_id_filter_sql(@filters[:submission_id])}
      AND #{submissions_survey_filter_sql(@filters[:market_ids])}
    SQL
  end

  def get_last_reportee_for_sheet(sheet_name)
    @last_reportee_for_sheet ||= {}
    @last_reportee_for_sheet[sheet_name]
  end

  def set_last_reportee_for_sheet(sheet_name, new_reportee)
    @last_reportee_for_sheet ||= {}
    @last_reportee_for_sheet[sheet_name] = new_reportee
  end

  def answers_rows
    if @reportee
      if get_last_reportee_for_sheet(:answers_rows) != @reportee
        set_last_reportee_for_sheet(:answers_rows, @reportee)

        @answers_rows = postgres_execute(answers_sql, readonly: true)
      end

      @answers_rows
    else
      @answers_rows ||= postgres_execute(answers_sql, readonly: true)
    end
  end

  def custom_content_link_click_rows
    if @reportee
      if get_last_reportee_for_sheet(:custom_content_link_click_rows) != @reportee
        set_last_reportee_for_sheet(:custom_content_link_click_rows, @reportee)

        @custom_content_link_click_rows = postgres_execute(custom_content_link_click_sql, readonly: true)
      end

      @custom_content_link_click_rows
    else
      @custom_content_link_click_rows ||= postgres_execute(custom_content_link_click_sql, readonly: true)
    end
  end

  def custom_content_link_mapper(answer: {})
    map = {
      "Date" => answer["date"],
      "Time" => answer["time"],
      "Survey Group Name" => answer["survey_group_name"],
      "Survey Name" => answer["survey_name"],
      "Card Name" => answer["question"],
      "Link Text" => answer["link_text"],
      "Card Name Base" => answer["base_question_content"],
      "Link URL" => answer["link_url"],
      "Language Code" => answer["language_code"],
      "Locale Code" => answer["locale_code"],
      "Survey Group ID" => answer["survey_group_id"],
      "Question Group ID" => answer["question_group_id"],
      "SurveyID" => answer["survey_id"],
      "QuestionID" => answer["question_id"],
      "LinkID" => answer["link_id"],
      "SubmissionID" => answer["submission_id"],
      "Custom Data" => answer["custom_data"],
      "Pageview Count" => answer["pageview_count"],
      "Visit Count" => answer["visit_count"],
      "IP Address" => answer["ip_address"],
      "Device Type" => answer["device_type"],
      "DeviceUDID" => answer["udid"],
      "Client Key" => answer["client_key"],
      "Completion URL" => answer["url"],
      "View Name" => answer["view_name"],
      "Event" => answer["pseudo_event"],
      "Device Data" => answer["device_data"],
      "Previous Surveys" => answer["previous_surveys"],
      "OS" => answer["os"],
      "Browser" => answer["browser"],
      "Browser Version" => answer["browser_version"],
      "Channel" => answer["channel"]
    }

    map.delete("IP Address") unless @include_ip_column
    ["Language Code", "Locale Code", "Survey Group ID", "Survey Group Name", "Question Group ID", "Card Name Base"].each { |key| map.delete(key) } unless localized_report?

    map
  end

  def answer_mapper(answer: {})
    map = {
      'Date'                          => answer['date'],
      'Time'                          => answer['time'],
      'Survey Group Name'             => answer['survey_group_name'],
      'Survey Name'                   => answer['survey_name'],
      'Question'                      => answer['question'],
      'Response'                      => answer['response'],
      'Question Base'                 => answer['base_question_content'],
      'Response Base'                 => answer['base_possible_answer_content'],
      'Translated Free Text Response' => answer['translated_response'],
      'Tags'                          => answer['tags'],
      'Language Code'                 => answer['language_code'],
      'Locale Code'                   => answer['locale_code'],
      'Survey Group ID'               => answer['survey_group_id'],
      'Question Group ID'             => answer['question_group_id'],
      'Response Group ID'             => answer['response_group_id'],
      'Next Question Group ID'        => answer['next_question_locale_group_id'],
      'SurveyID'                      => answer['survey_id'],
      'QuestionID'                    => answer['question_id'],
      'ResponseID'                    => answer['response_id'],
      'NextQuestionID'                => answer['next_question_id'],
      'Pageview Count'                => answer['pageview_count'],
      'Visit Count'                   => answer['visit_count'],
      'IP Address'                    => answer['ip_address'],
      'Device Type'                   => answer['device_type'],
      'DeviceUDID'                    => answer['udid'],
      'DeviceUDID SubmissionID'       => answer['device_udid_submission_id'],
      'Client Key'                    => answer['client_key'],
      'Completion URL'                => answer['url'],
      'View Name'                     => answer['view_name'],
      'Event'                         => answer['pseudo_event'],
      'Context data'                  => answer['custom_data'],
      'Device data'                   => answer['device_data'],
      'Previous Surveys'              => answer['previous_surveys'],
      'Sentiment Score'               => answer['score'],
      'Sentiment Magnitude'           => answer['magnitude'],
      'Entity 1 name'                 => answer['entity_1_name'],
      'Entity 1 type'                 => answer['entity_1_type'],
      'Entity 2 name'                 => answer['entity_2_name'],
      'Entity 2 type'                 => answer['entity_2_type'],
      'Entity 3 name'                 => answer['entity_3_name'],
      'Entity 3 type'                 => answer['entity_3_type'],
      'Entity 4 name'                 => answer['entity_4_name'],
      'Entity 4 type'                 => answer['entity_4_type'],
      'OS'                            => answer['os'],
      'Browser'                       => answer['browser'],
      'Browser Version'               => answer["browser_version"]&.strip,
      'Channel'                       => answer['channel']
    }
    map.delete('IP Address') unless @include_ip_column
    ['Language Code', 'Locale Code', 'Survey Group ID', 'Survey Group Name', 'Question Group ID', 'Question Base', 'Response Group ID',
     'Response Base', 'Next Question Group ID'].each { |key| map.delete(key) } unless localized_report?
    map
  end

  def report_job_in_progress!
    @report_job.status = :in_progress
    @report_job.save
  end

  def report_job_as_done!
    @report_job.status = :done
    @report_job.save
  end

  def report_job_save_url!
    @report_job.report_url = @file_url
    @report_job.save
  end

  def init_xlsx_file
    p = Axlsx::Package.new
    p.use_shared_strings = true
    @wb = p.workbook
    @wrap = @wb.styles.add_style alignment: { horizontal: :left, vertical: :center, wrap_text: true }
    @normal_cell = @wb.styles.add_style alignment: { horizontal: :left, vertical: :center }
    @tr_cell = @wb.styles.add_style u: true, alignment: { horizontal: :center, vertical: :center }
    @td_cell = @wb.styles.add_style alignment: { horizontal: :center, vertical: :center }
    @section_title = @wb.styles.add_style bg_color: 'E1E1E1', sz: 16, alignment: { horizontal: :left, vertical: :center }

    p
  end

  def generate_xlsx(date_format: DATE_FORMAT)
    tagged_logger.info "Generating report"

    xlsx_package = init_xlsx_file

    survey_metadata
    aggregate_results_by_day(date_format: date_format)
    questions

    if individual_rows_exceeded?
      tagged_logger.info "Individual Row limit exceeded -- generating CSV file"
      generate_csv
      csv_url = upload_csv_file
      @report_csv_urls[localized_report? ? :locale_groups : :surveys][@reportee.id] = csv_url
    else
      individual_rows
    end

    custom_content_link_clicks_sheet if include_link_clicks?

    devices

    tagged_logger.info "Done generating report"

    xlsx_package
  end

  def upload_xlsx_file
    return 'www.placeholder_for_tests.ca/xlsx' unless %w(production staging develop).include? Rails.env

    obj = s3_bucket.object(xlsx_filename)
    file_path = Dir.glob(xlsx_filepath).first
    obj.upload_file(file_path)
    obj.presigned_url(:get, expires_in: 7 * 86400) # expires in 7 days
  end

  def xlsx_filepath
    "tmp/#{xlsx_filename}"
  end

  def individual_rows_exceeded?
    answers_rows.count > LIMIT_FOR_INDIVIDUAL_XLSX
  end

  def attach_csv_file_to_email?
    return false unless individual_rows_exceeded?

    attach_file_to_email?(:csv)
  end

  def attach_file_to_email?(file_type = :xlsx)
    filepath = case file_type
    when :xlsx
      xlsx_filepath
    when :csv
      individual_rows_filepath
    end

    File.size("#{Rails.root}/#{filepath}").to_f / 1_000_000 <= 10
  end

  def human_date_range
    @date_range ? [@date_range.first, @date_range.last].map { |date| date.strftime(DATE_FORMAT) }.join(' to ') : 'All time'
  end

  def email_params
    {
      account: @account,
      reportee_survey_ids: reportee_surveys.pluck(:id), # could be pure Array
      report_name: xlsx_filename,
      report_path: xlsx_filepath,
      report_url: @file_url,
      date_range: @date_range,
      impressions_count: @blended_impression_size,
      submissions_count: @submission_size,
      submission_rate: @submission_rate,
      attach_file: attach_file_to_email?
    }
  end

  def localized_report?
    @reportee.is_a?(SurveyLocaleGroup) || @reportee.localized?
  end

  def reportee_surveys
    return [@reportee] if @reportee.is_a? Survey

    if @scheduled_report&.all_surveys || @partially_selected_report.blank?
      @reportee.surveys
    else
      @partially_selected_report.surveys
    end
  end

  def reportee_questions
    case @reportee
    when SurveyLocaleGroup
      @reportee.base_questions
    when Survey
      @reportee.localized? ? @reportee.survey_locale_group.base_questions : @reportee.questions
    end
  end

  def localized_question_answer_count(localized_question)
    return 0 unless localized_report?

    reportee_questions = localized_question.question_locale_group.questions.where(survey: reportee_surveys)
    answers = Answer.where(question: reportee_questions)
    answers = answers.where(created_at: @date_range) if @date_range

    Answer.answers_count(answers, ignore_multiple_type_dup: true, filters: @filters)
  end

  def localized_possible_answer_answer_count(localized_possible_answer)
    return 0 unless localized_report?

    reportee_questions = localized_possible_answer.question.question_locale_group.questions.where(survey: reportee_surveys)
    reportee_possible_answers = localized_possible_answer.possible_answer_locale_group.possible_answers.where(question: reportee_questions)
    answers = Answer.where(possible_answer: reportee_possible_answers)
    answers = answers.where(created_at: @date_range) if @date_range

    Answer.answers_count(answers, filters: @filters)
  end

  def compute_survey_stats
    switched_at = @account.viewed_impressions_calculation_start_at

    @survey_stats_per_day = postgres_execute(survey_stats_per_day_sql, readonly: true)
    @survey_stats_per_day = @survey_stats_per_day.map do |stats|
      stats['blended_impression_count'] = stats['created_date'] >= switched_at ? stats['viewed_impression_count'] : stats['impression_count']
      stats['submission_rate'] = percent_of(stats['submission_count'].to_i, stats['blended_impression_count'].to_i)
      stats
    end

    @blended_impression_size, @submission_size = [0] * 2
    @survey_stats_per_day.each do |submission_stats|
      @blended_impression_size += submission_stats['blended_impression_count'].to_i
      @submission_size += submission_stats['submission_count'].to_i
    end
    @submission_rate = percent_of(@submission_size, @blended_impression_size)
  end

  def s3_bucket
    s3_client.bucket(s3_bucket_name)
  end

  def s3_bucket_name
    if Rails.env.production?
      'pi-reports'
    elsif Rails.env.staging?
      'pi-staging-reports'
    elsif Rails.env.develop?
      'pi-develop-reports'
    end
  end

  def s3_client
    Aws::S3::Resource.new(region: 'us-west-2')
  end
end
