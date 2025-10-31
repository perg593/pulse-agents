# frozen_string_literal: true

module Admin
  class SubmissionGeneratorPresenter
    include Rails.application.routes.url_helpers

    def props
      {
        formUrl: sample_generator_admin_submissions_path,
        questionLookupUrl: admin_questions_path
      }
    end

    def questions(survey_id)
      Survey.find(survey_id).questions.map do |question|
        {
          id: question.id,
          content: question.content,
          possibleAnswers: possible_answers(question)
        }
      end
    end

    private

    def possible_answers(question)
      question.possible_answers.sort_by_position.map do |possible_answer|
        {
          id: possible_answer.id,
          content: possible_answer.content
        }
      end
    end
  end
end
