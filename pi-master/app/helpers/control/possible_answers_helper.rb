# frozen_string_literal: true

module Control
  module PossibleAnswersHelper
    def next_question_options(base_survey)
      base_survey.questions.map(&:question_locale_group).
        reject { |question_locale_group| question_locale_group == @possible_answer_locale_group.question_locale_group }.
        compact.
        map { |question_locale_group| [question_locale_group.name, question_locale_group.id] }
    end
  end
end
