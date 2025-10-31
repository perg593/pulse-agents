# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module Submissions
    AnswerSuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(Common::PollResponseSchema)
    end

    EmailAnswerSuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(Common::PollResponseSchema)
    end

    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
