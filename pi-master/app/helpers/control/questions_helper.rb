# frozen_string_literal: true

module Control
  module QuestionsHelper
    def alignment_is?(question:, device_type:, width_type:, alignment:)
      case device_type
      when 'desktop'
        return false unless question.desktop_width_type == width_type

        question.answers_alignment_desktop == alignment
      when 'mobile'
        return false unless question.mobile_width_type == width_type

        question.answers_alignment_mobile == alignment
      end
    end

    def alignment_description(alignment)
      descriptions = {
        'space_between' => 'Items are evenly distributed.',
        'space_around' => 'Items have equal space around them.',
        'space_evenly' => 'The spacing between any two items is equal.'
      }
      descriptions[alignment]
    end

    def last_response?(index, possible_answers)
      index == possible_answers.length - 1
    end

    def print_question_type(question)
      case question.question_type
      when "single_choice_question"
        question.nps? ? "NPS" : "Single Choice"
      when "free_text_question"
        "Free Text Capture"
      when "custom_content_question"
        "Custom Content"
      when "multiple_choices_question"
        "Multiple Choice Question"
      else
        Rollbar.error(ArgumentError, "Question with unrecognized question_type", question: question)
        question.question_type || "unknown question type"
      end
    end

    def question_randomization_options
      Question::RANDOMIZE_OPTIONS.dup.prepend(['do not randomize', nil]).map { |label, value| [label.titleize, value] }
    end
  end
end
