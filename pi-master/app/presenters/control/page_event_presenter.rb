# frozen_string_literal: true

module Control
  class PageEventPresenter
    include Rails.application.routes.url_helpers

    COLOR_PALETTE = %w(#9B62A7 #6F4C9B #5568B8 #4D8AC6 #549EB3 #60AB9E #77B77D #A6BE54 #E49C39 #E67932 #95211B).freeze

    attr_accessor :filters

    def initialize(survey:, question: nil, event: nil, filters: {})
      @survey = survey
      @question = question
      @event = event
      @filters = filters
    end

    def page_event_params
      questions = @survey.questions.where(question_type: %i(single_choice_question multiple_choices_question))
      events = @survey.account.page_events.select(:name).order(:name).group(:name) # TODO: Create a meta table for performance

      @question ||= questions.first
      @event ||= events[0] # '.first' would invoke 'ORDER BY id'
      return if @question.nil? || @event.nil?

      {
        questions: questions.map { |q| { id: q.id, content: q.content } }, events: events, selectedQuestion: selected_question_data,
        selectedEvent: { name: @event.name }, itemUpdateUrl: page_event_data_survey_path(@survey)
      }
    end

    # TODO: Rename this vague method name
    def item_update_params
      return if @question.nil? || @event.nil?
      selected_question_data
    end

    private

    # TODO: Separate a question and possible answers
    def selected_question_data
      question_answer_count = @question.answers_count(filters: @filters)
      possible_answer_data = @question.possible_answers.includes(:answers).map do |pa|
        pa_answer_count = pa.answers_count(filters: @filters)
        pa_answer_rate = question_answer_count.zero? ? 0 : (pa_answer_count.to_f * 100 / question_answer_count).round
        event_answer_count = pa.event_answer_count(@event.name, filters: @filters)
        event_answer_rate = pa_answer_count.zero? ? 0 : (event_answer_count.to_f * 100 / pa_answer_count).round
        { id: pa.id, content: pa.content, color: color(@question.id, pa), colorUpdateUrl: "/possible_answers/#{pa.id}/update_color",
          answerCount: pa_answer_count, answerRate: pa_answer_rate, eventAnswerCount: event_answer_count, eventAnswerRate: event_answer_rate }
      end
      { id: @question.id, content: @question.content, answerCount: question_answer_count, possibleAnswers: possible_answer_data }
    end

    # TODO: DRY off with SurveyReportPresenter
    def color(question_level_id, possible_answer_level_record)
      key = "#{question_level_id}_#{possible_answer_level_record.id}"

      @color_cache ||= {}

      @color_cache[key] ||= possible_answer_level_record.report_color

      @color_index ||= 0
      unless @color_cache[key]
        @color_cache[key] = COLOR_PALETTE[@color_index]
        @color_index += 1
        @color_index = 0 if @color_index >= COLOR_PALETTE.size
      end

      @color_cache[key]
    end
  end
end
