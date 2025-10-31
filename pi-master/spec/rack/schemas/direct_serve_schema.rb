# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module DirectServe
    DeviceSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:udid).value(:string) # TODO: consider specifying structure
      required(:client_key).maybe(:string)
    end

    SuccessfulResponseSchema = Dry::Schema.JSON do
      # 0=>, 1=> type keys are not supported :(
      # config.validate_keys = true

      required(:survey).value(Common::DirectSurveySchema)
      required(:questions_and_possible_answers).value(Dry.Types::Array.of(Common::BaseQuestionSchema)) # Specific question types are tested elsewhere
      required(:device).value(DeviceSchema)
      required(:device_data).maybe(:hash) # Arbitrary user-provided data
      required(:submission).value(Common::SubmissionSchema)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
