# frozen_string_literal: true
module RackSchemas
  module Results
    PossibleAnswerResultsSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:position).value(:integer)
      required(:content).value(:string)
      required(:numAnswers).value(:integer)
    end

    QuestionResultsSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:position).value(:integer)
      required(:content).value(:string)
      required(:possibleAnswers).value(Dry.Types::Array.of(PossibleAnswerResultsSchema))
    end

    ResultsSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:questions).value(Dry.Types::Array.of(QuestionResultsSchema))
    end

    SuccessfulJSONResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:results).value(ResultsSchema)
    end

    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::String
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
