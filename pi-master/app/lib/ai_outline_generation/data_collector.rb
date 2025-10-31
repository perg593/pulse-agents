# frozen_string_literal: true

module AIOutlineGeneration
  # Data collector that orchestrates all providers
  class DataCollector
    include Logging

    def initialize(job)
      @job = job
    end

    def survey_data
      @survey_data ||= DataProviders::SurveyDataProvider.new(@job).call
    end

    def ai_analysis_data
      @ai_analysis_data ||= DataProviders::AIAnalysisProvider.new(@job).call
    end

    def device_data
      @device_data ||= DataProviders::DeviceDataProvider.new(@job, survey_data).call
    end

    # Collect all data in one call for convenience
    def all_data
      {
        survey_data: survey_data,
        ai_analysis_data: ai_analysis_data,
        device_data: device_data
      }
    end

    private

    attr_reader :job
  end
end
