# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength - long because this aims to test all columns
module ReportHelper
  include Numerable

  # rubocop:disable Metrics/AbcSize it's necessarily complicated
  def accurate_report_overview_sheet(reportee, worksheet)
    reportee_type = reportee.is_a?(SurveyLocaleGroup) ? 'Survey Group' : 'Survey'

    report_dates = if report_filters[:date_range]
      "#{report_filters[:date_range].first.strftime('%m/%d/%Y')} to #{report_filters[:date_range].last.strftime('%m/%d/%Y')}"
    else
      'All time'
    end

    expect(worksheet.rows.count).to eq 5
    expect(worksheet).to have_header_cells ["PULSE INSIGHTS #{reportee_type.upcase} REPORTING"] + ([nil] * 9)
    expect(worksheet).to have_cells(["#{reportee_type} Name:", reportee.name]).in_row(1)
    expect(worksheet).to have_cells(["Author:", reportee.updated_by_name]).in_row(2)
    expect(worksheet).to have_cells(["Reporting Dates:", report_dates]).in_row(3)
    expect(worksheet).to have_cells(["Report Generated:", Time.current.strftime("%m/%d/%Y")]).in_row(4)
  end

  # rubocop:disable Metrics/MethodLength
  def accurate_summary_by_day_sheet(reportee, worksheet, date_format: "%m/%d/%Y")
    impressions = Submission.where(survey: reportee_surveys)
    impressions = Submission.filtered_submissions(impressions, filters: report_filters)

    num_rows = 3 + impressions.map { |impression| impression.created_at.in_time_zone(zone).to_date }.uniq.count

    expect(worksheet.rows.count).to eq num_rows
    expect(worksheet).to have_header_cells ["SUMMARY STATS BY DAY"] + ([nil] * 9)

    expect(worksheet).to have_cells(["Date", "Impressions", "Submissions", "Submission Rate"]).in_row(1)

    impressions_by_date = impressions.order(created_at: :desc).group_by { |impression| impression.created_at.in_time_zone(zone).to_date }

    total_blended_impressions = 0

    impressions_by_date.each_with_index do |date_and_impressions, index|
      date = date_and_impressions.first
      impressions_for_the_day = date_and_impressions.last

      num_impressions = impressions_for_the_day.count
      num_viewed_impressions = impressions_for_the_day.count { |impression| impression.viewed_at.present? }
      num_submissions = impressions_for_the_day.count { |impression| impression.answers_count > 0 }

      num_blended_impressions = date >= reportee.account.viewed_impressions_calculation_start_at ? num_viewed_impressions : num_impressions
      submission_percentage = percent_of(num_submissions, num_blended_impressions)
      total_blended_impressions += num_blended_impressions

      formatted_date = date.strftime(date_format)

      expect(worksheet).to have_cells([formatted_date, num_blended_impressions, num_submissions, submission_percentage]).in_row(2 + index)
    end

    total_submissions = impressions.where('answers_count > 0').count
    total_sub_percentage = percent_of(total_submissions, total_blended_impressions)

    total_results_row_index = num_rows - 1
    expected_total_results_row = ["TOTAL", total_blended_impressions, total_submissions, total_sub_percentage]
    expect(worksheet).to have_cells(expected_total_results_row).in_row(total_results_row_index)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def accurate_response_summaries_sheet(reportee, worksheet)
    questions =
      case reportee
      when SurveyLocaleGroup
        reportee.base_questions
      when Survey
        reportee.localized? ? reportee.survey_locale_group.base_questions : reportee.questions
      end
    # headers + num question + answers + spaces between questions
    num_rows = 2 + questions.count + PossibleAnswer.where(question: questions).count + questions.count
    expect(worksheet.rows.count).to eq num_rows

    expect(worksheet).to have_header_cells ["RESPONSE SUMMARIES"] + ([nil] * 9)

    index = 1

    expect(worksheet).to have_cells([nil, nil, nil, "Responses", "Share"]).in_row(index)
    index += 1

    # TODO: Explicitly test that free text answers are not included
    questions.each do |question|
      reportee_questions = question.question_locale_group.questions.where(survey: reportee_surveys) if localized_report?

      answers = localized_report? ? Answer.where(question: reportee_questions) : question.answers
      question_answer_count = Answer.answers_count(answers, ignore_multiple_type_dup: true, filters: report_filters)

      expect(worksheet).to have_cells([question.content, nil, nil, question_answer_count, nil]).in_row(index)
      index += 1

      index += 1 and next if question.question_type == :free_text_question

      question.possible_answers.sort_by_position.each do |possible_answer|
        answer_count =
          if localized_report?
            reportee_possible_answers = possible_answer.possible_answer_locale_group.possible_answers.where(question: reportee_questions)
            answer_count_scope = Answer.where(possible_answer: reportee_possible_answers)
            Answer.answers_count(answer_count_scope, filters: report_filters)
          else
            possible_answer.answers_count(filters: report_filters)
          end
        expected_answer_rate = percent_of(answer_count, question_answer_count)
        expect(worksheet).to have_cells(["  #{possible_answer.content}", nil, nil, answer_count, expected_answer_rate]).in_row(index)
        index += 1
      end
      index += 1
    end
  end

  # rubocop:disable Layout/LineLength - For the long header
  def accurate_individual_responses_sheet(_reportee, worksheet)
    answers = Answer.where(question: Question.where(survey: reportee_surveys))
    answers = Answer.filtered_answers(answers, filters: report_filters)
    expect(worksheet.rows.count).to eq(answers.count + 1)

    expected_header = ["Date", "Time", "Survey Group Name", "Survey Name", "Question", "Response", "Question Base", "Response Base", "Translated Free Text Response", "Tags", "Language Code", "Locale Code", "Survey Group ID", "Question Group ID", "Response Group ID", "Next Question Group ID", "SurveyID", "QuestionID", "ResponseID", "NextQuestionID", "Pageview Count", "Visit Count", "IP Address", "Device Type", "DeviceUDID", "DeviceUDID SubmissionID", "Client Key", "Completion URL", "View Name", "Event", "Context data", "Device data", "Previous Surveys", "Sentiment Score", "Sentiment Magnitude", "Entity 1 name", "Entity 1 type", "Entity 2 name", "Entity 2 type", "Entity 3 name", "Entity 3 type", "Entity 4 name", "Entity 4 type", "OS", "Browser", "Browser Version", "Channel"]
    expected_header -= ['Language Code', 'Locale Code', 'Survey Group ID', 'Survey Group Name', 'Question Group ID', 'Question Base', 'Response Group ID', 'Response Base', 'Next Question Group ID'] unless localized_report?
    expect(worksheet).to have_header_cells expected_header

    index = 1
    answers.reorder(created_at: :desc).each do |answer|
      expected_cells =
        [
          answer.created_at.in_time_zone(zone).strftime("%m/%d/%Y"), # "Date"
          answer.created_at.in_time_zone(zone).strftime("%H:%M:%S"), # "Time"
          answer.survey.survey_locale_group&.name, # "Survey Group Name"
          answer.survey.name, # "Survey Name"
          answer.question.content, # "Question"
          answer.possible_answer.content, # "Response" TODO: handle free text case
          answer.question.question_locale_group&.base_question&.content, # "Question Base"
          answer.possible_answer.possible_answer_locale_group&.base_possible_answer&.content, # "Response Base"
          nil, # "Translated Free Text Response" TODO: handle free text case
          nil, # "Tags" TODO
          answer.survey.language_code, # "Language Code"
          answer.survey.locale_code, # "Locale Code"
          answer.survey.survey_locale_group_id, # "Survey Group ID"
          answer.question.question_locale_group_id, # "Question Group ID"
          answer.possible_answer.possible_answer_locale_group_id, # "Response Group ID"
          Question.find_by(id: answer.next_question_id)&.question_locale_group_id, # "Next Question Group ID"
          answer.survey.id, # "SurveyID"
          answer.question_id, # "QuestionID"
          answer.possible_answer_id, # "ResponseID"
          answer.next_question_id, # "NextQuestionID"
          nil, # "Pageview Count" TODO
          nil, # "Visit Count" TODO
          answer.submission.ip_address, # "IP Address"
          answer.submission.device_type, # "Device Type"
          answer.device.udid, # "DeviceUDID"
          "#{answer.device.udid}_#{answer.submission.id}", # "DeviceUDID SubmissionID"
          nil, # "Client Key" TODO
          answer.submission.url, # "Completion URL"
          nil, # "View Name" TODO
          nil, # "Event" TODO
          nil, # "Context data" TODO
          nil, # "Device data" TODO
          answer.previous_surveys, # "Previous Surveys"
          nil, # "Sentiment Score" TODO
          nil, # "Sentiment Magnitude" TODO
          nil, # "Entity 1 name" TODO
          nil, # "Entity 1 type" TODO
          nil, # "Entity 2 name" TODO
          nil, # "Entity 2 type" TODO
          nil, # "Entity 3 name" TODO
          nil, # "Entity 3 type" TODO
          nil, # "Entity 4 name" TODO
          nil, # "Entity 4 type" TODO
          nil, # "OS" TODO
          "Unknown", # "Browser" TODO
          "Unknown", # "Browser version" TODO
          answer.submission.channel # "Channel"
        ]
      # TODO: make it less dependent on magic numbers
      # 'Language Code', 'Locale Code', 'Survey Group ID', 'Survey Group Name', 'Question Group ID', 'Question Base', 'Response Group ID', 'Response Base', 'Next Question Group ID'
      expected_cells.delete_if.with_index { |_, i| [10, 11, 12, 2, 13, 6, 14, 7, 15].include? i } unless localized_report?
      expect(worksheet).to have_cells(expected_cells).in_row(index)

      index += 1
    end
  end

  # rubocop:disable Metrics/PerceivedComplexity
  # This is long for readability
  def accurate_responses_by_device_sheet(reportee, worksheet)
    answers = Answer.where(question: Question.where(survey: reportee_surveys))
    answer_count = Answer.answers_count(answers, filters: report_filters)

    expect(worksheet.rows.count).to eq(answer_count + 1)

    expected_headers = ["DeviceUDID", "Device Type", "Client Key", "Date", "Time", "Survey Group Name", "Survey Group ID", "Survey Name", "SurveyID", "Pageview Count", "Visit Count", "Completion URL", "View Name", "IP Address", "Event", "Context Data", "Device Data", "Sentiment Score", "Sentiment Magnitude", "Entity 1 name", "Entity 1 type", "Entity 2 name", "Entity 2 type", "Entity 3 name", "Entity 3 type", "Entity 4 name", "Entity 4 type", "OS", "Browser", "Browser Version", "Channel"]
    expected_headers -= ['Survey Group Name', 'Survey Group ID'] unless localized_report?

    # TODO: Free text answers have different headers
    # TODO: Test for gaps from unanswered questions
    questions =
      case reportee
      when SurveyLocaleGroup
        reportee.base_questions
      when Survey
        reportee.localized? ? reportee.survey_locale_group.base_questions : reportee.questions
      end
    questions.each do |_question|
      expected_headers += %w(Question QuestionID ResponseID Response)
      expected_headers += ['Question Base', 'Question Group ID', 'Response Base', 'Response Group ID'] if localized_report?
    end

    expect(worksheet).to have_header_cells expected_headers
    index = 1

    submissions = Submission.where('answers_count > 0').where(survey: reportee_surveys).order(created_at: :asc)
    submissions = Submission.filtered_submissions(submissions, filters: report_filters)

    submissions.group_by(&:device_id).each do |device_id, submissions_per_device|
      device = Device.find(device_id)
      submissions_per_device.each do |submission|
        cells = [
          device.udid, # DeviceUDID
          submission.device_type, # Device Type
          device.client_key, # Client Key
          submission.created_at.in_time_zone(zone).strftime("%m/%d/%Y"), # Date
          submission.created_at.in_time_zone(zone).strftime("%H:%M:%S"), # Time
          submission.survey.survey_locale_group&.name, # Survey Group Name
          submission.survey.survey_locale_group_id, # Survey Group ID
          submission.survey.name, # "Survey Name"
          submission.survey_id, # SurveyID
          nil, # Pageview Count TODO
          nil, # Visit Count TODO
          submission.url, # Completion URL
          nil, # View Name TODO
          submission.ip_address, # "IP Address"
          nil, # Event TODO
          nil, # Context Data TODO
          nil, # Device Data TODO
          nil, # Sentiment Score TODO
          nil, # Sentiment Magnitude TODO
          nil, # Entity 1 name TODO
          nil, # Entity 1 type TODO
          nil, # Entity 2 name TODO
          nil, # Entity 2 type TODO
          nil, # Entity 3 name TODO
          nil, # Entity 3 type TODO
          nil, # Entity 4 name TODO
          nil, # Entity 4 type TODO
          nil, # OS TODO
          "Unknown", # Browser TODO
          "Unknown", # Browser Version TODO
          submission.channel # Channel
        ]
        # TODO: make it less dependent on magic numbers
        # Survey Group Name, Survey Group ID
        2.times { cells.delete_at(5) } unless localized_report?

        submission.survey.questions.each do |question|
          possible_answer = submission.answers.find_by(question_id: question.id)&.possible_answer

          cells += [
            question.content,
            question.id,
            possible_answer&.id || "", # TODO: handle free text case
            possible_answer&.content || "" # TODO: handle free text case
          ]

          next unless localized_report?

          cells += [
            question.question_locale_group.base_question.content,
            question.question_locale_group.id,
            possible_answer&.possible_answer_locale_group&.base_possible_answer&.content || "",
            possible_answer&.possible_answer_locale_group&.id || ""
          ]
        end

        expect(worksheet).to have_cells(cells).in_row(index)

        index += 1
      end
    end
  end

  # TODO: differentiate methods between standard report and localized report
  alias accurate_localized_summary_by_day_sheet accurate_summary_by_day_sheet
  alias accurate_localized_response_summaries_sheet accurate_response_summaries_sheet
  alias accurate_localized_individual_responses_sheet accurate_individual_responses_sheet
  alias accurate_localized_responses_by_device_sheet accurate_responses_by_device_sheet

  def find_worksheet_by_name(xlsx_package, name)
    xlsx_package.workbook.worksheets.detect { |worksheet| worksheet.name == name }
  end

  def report_overview_summary_by_day_worksheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Survey metadata")
  end

  def summary_by_day_worksheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Aggregate results by day")
  end

  def response_summaries_worksheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Questions")
  end

  def individual_responses_worksheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Individual rows")
  end

  def device_worksheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Devices")
  end

  def custom_content_links_sheet(xlsx_package)
    find_worksheet_by_name(xlsx_package, "Custom Content Clicks")
  end

  def report_filters
    @filters || {}
  end

  def zone
    'GMT'
  end
end
