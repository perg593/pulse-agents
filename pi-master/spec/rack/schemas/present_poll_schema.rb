# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module PresentPoll
    SuccessfulResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:survey).value(Common::PresentEventSurveySchema)
      required(:question).value(Common::PollQuestionSchema) # Specific question types are tested elsewhere
      required(:results).value(Dry.Types::Array.of(Common::PollResponseSchema))
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
