# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module Serve
    DeviceSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:udid).value(:string) # TODO: consider specifying structure
    end

    SuccessfulResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:survey).value(Common::SurveySchema)
      required(:device).value(DeviceSchema)
      required(:device_data).maybe(:hash) # Arbitrary user-provided data
      required(:submission).value(Common::SubmissionSchema)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
