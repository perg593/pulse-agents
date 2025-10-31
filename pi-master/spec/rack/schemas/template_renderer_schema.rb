# frozen_string_literal: true

module RackSchemas
  module TemplateRenderer
    AnswerInfoSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(QuestionSchema)
    end

    QuestionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      require(:question).value(:string)
      require(:type).value(:string)

      Dry.Types::Array.of(PossibleAnswerSchema)
    end

    PossibleAnswerSchema = Dry::Schema.JSON do
      config.validate_keys = true

      require(:content).value(:string)
      require(:selected).value(:bool)
    end
  end
end
