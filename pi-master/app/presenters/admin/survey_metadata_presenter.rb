# frozen_string_literal: true

module Admin
  class SurveyMetadataPresenter
    def initialize(survey)
      @survey = survey
    end

    def props
      return {} if @survey.nil?

      { survey: survey_props(@survey) }
    end

    private

    def survey_props(survey)
      questions = survey.questions.map do |question|
        question_props(question)
      end

      {
        id: survey.id,
        name: survey.name,
        questions: questions,
        metadatum: metadatum_for_record(survey)
      }
    end

    def possible_answer_props(possible_answer)
      {
        id: possible_answer.id,
        content: possible_answer.content,
        metadatum: metadatum_for_record(possible_answer)
      }
    end

    def question_props(question)
      possible_answers = question.possible_answers.map do |possible_answer|
        possible_answer_props(possible_answer)
      end

      {
        id: question.id,
        content: question.content,
        possibleAnswers: possible_answers,
        metadatum: metadatum_for_record(question)
      }
    end

    def metadatum_for_record(record)
      return unless record.metadatum

      {
        id: record.metadatum.id,
        name: record.metadatum.name
      }
    end
  end
end
