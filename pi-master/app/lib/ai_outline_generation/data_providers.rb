# frozen_string_literal: true

require "logging"

module AIOutlineGeneration
  module DataProviders
    # Base class for all data providers
    class Base
      include Logging
      include SQLHelpers

      def initialize(job)
        @job = job
        @survey = job.survey
      end

      # Each provider should implement this method
      def call
        raise NotImplementedError, "Subclasses must implement #call"
      end

      private

      attr_reader :job, :survey
    end
  end
end
