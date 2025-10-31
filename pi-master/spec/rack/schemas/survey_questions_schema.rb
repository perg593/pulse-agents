# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module SurveyQuestions
    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(Common::BaseQuestionSchema) # Specific question types are tested elsewhere
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
