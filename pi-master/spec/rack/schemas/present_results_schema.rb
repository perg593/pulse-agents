# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module PresentResults
    PollResultSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:string)
      required(:content).value(:string)
      required(:count).value(:integer)
    end

    ThankYouAndPollResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:poll).value(Dry.Types::Array.of(PollResultSchema))
      required(:content).value(:string)
      required(:question_type).value(:string)
      required(:answers_via_checkbox).value(Dry.Types::Array.of(:string))
    end

    ThankYouResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:thank_you).value(:string)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
