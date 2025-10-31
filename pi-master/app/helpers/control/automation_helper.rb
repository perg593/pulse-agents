# frozen_string_literal: true

module Control
  module AutomationHelper
    def trigger_type_input_pairs
      ['Matches any one of', 'Matches all of'].zip Automation.trigger_types.keys
    end

    def condition_type_input_pairs
      ['Submission', 'Tag Initialization (Pageview)'].zip Automation.condition_types.keys
    end

    def action_type_input_pairs
      ['Send An Email', 'Track An Event'].zip Automation.action_types.keys
    end

    def url_matcher_input_pairs
      ['Is', 'Containing', 'Regex matches'].zip AutomationCondition.url_matchers.keys
    end

    def question_input_pairs(questions)
      questions.map { |question| ["[#{question.survey.name}] #{question.content}", question.id] }.unshift(['Any question', nil])
    end
  end
end
