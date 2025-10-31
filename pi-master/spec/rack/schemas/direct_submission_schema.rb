# frozen_string_literal: true
module RackSchemas
  module DirectSubmission
    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
