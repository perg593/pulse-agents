# frozen_string_literal: true

module AIOutlineGeneration
  module DataProviders
    class DeviceDataProvider < Base
      def initialize(job, survey_data)
        super(job)
        @survey_data = survey_data
      end

      def call
        {
          device_summary: build_device_summary,
          questions_data: group_questions_data
        }
      end

      private

      attr_reader :survey_data

      def build_device_summary
        sample_data = survey_data[:devices_data].first(3)
        return "No device data available" unless sample_data.any?

        devices = sample_data.map { |d| d['device_type'] }.compact.uniq
        browsers = sample_data.map { |d| d['browser'] }.compact.uniq
        "Device types: #{devices.join(', ')}; Browsers: #{browsers.join(', ')}"
      end

      def group_questions_data
        survey_data[:devices_data].group_by { |row| row['question_content'] }
      end
    end
  end
end
