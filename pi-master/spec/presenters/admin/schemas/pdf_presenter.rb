# frozen_string_literal: true

module Schemas
  module PDFPresenter
    FileSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:name).value(:string)
      optional(:position).value(:integer)
    end

    SurveySchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:integer)
      required(:name).value(:string)
    end

    PropsSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:survey).value(SurveySchema)

      required(:templateFile).value(FileSchema)
      required(:assetFiles).value(Dry.Types::Array.of(FileSchema))
      required(:staticPdfFiles).value(Dry.Types::Array.of(FileSchema))
    end
  end
end
