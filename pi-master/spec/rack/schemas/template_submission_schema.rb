# frozen_string_literal: true

module RackSchemas
  module PDFTemplates
    PossibleAnswerSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:content).value(:string)
      required(:metaname).value(:string)
    end

    QuestionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:type).value(:string)
      required(:content).value(:string)
      required(:metaname).value(:string)
      required(:possible_answers).value(Dry.Types::Array.of(PossibleAnswerSchema))
    end

    TemplateSubmissionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:questions).value(Dry.Types::Array.of(QuestionSchema))
    end
  end
end
