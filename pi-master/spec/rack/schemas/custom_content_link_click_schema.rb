# frozen_string_literal: true

module RackSchemas
  module CustomContentLinkClick
    SuccessfulResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
