# frozen_string_literal: true
module RackSchemas
  module Heartbeat
    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
