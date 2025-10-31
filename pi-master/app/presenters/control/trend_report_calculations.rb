# frozen_string_literal: true

module Control
  module TrendReportCalculations
    private

    # Question and PossibleAnswer
    # QuestionLocaleGroup and PossibleAnswerLocaleGroup
    def trend_report_data(question_level_record, possible_answer_level_record)
      highcharts_trend_data(raw_chart_data(question_level_record, possible_answer_level_record))
    end

    def highcharts_trend_data(answers_by_creation_date)
      answers_by_creation_date.map do |(_possible_answer_id, creation_date), num_answers|
        # DateTime.to_i is in seconds, Highcharts needs it javascript style (ms)
        timestamp = creation_date.to_datetime.to_i * 1000

        [timestamp, num_answers]
      end
    end

    def date_grouping_sql
      "DATE(answers.created_at)"
    end

    def raw_chart_data(question_level_record, possible_answer_level_record)
      unless @last_q_id == question_level_record.id
        @last_q_id = question_level_record.id

        sanitized_id = ActiveRecord::Base.send(:sanitize_sql, "#{possible_answer_level_record.class.name.underscore}_id")

        scope = Answer.filtered_answers(question_level_record.answers, filters: @filters).
                order(Arel.sql(date_grouping_sql)).
                group(sanitized_id, Arel.sql(date_grouping_sql))

        if possible_answer_level_record.instance_of? PossibleAnswerLocaleGroup
          scope = scope.joins(:possible_answer, possible_answer: :possible_answer_locale_group)
        end

        @answer_counts = scope.count
      end

      @answer_counts.select do |(possible_answer_level_record_id, _creation_date), _num_answers|
        possible_answer_level_record_id == possible_answer_level_record.id
      end
    end
  end
end
