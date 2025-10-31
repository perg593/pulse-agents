# frozen_string_literal: true

module Rack
  module IntegrationSwitch
    DISABLED_INTEGRATIONS_BY_ENV = {
      'development' => %w(rollbar rack_attack influxdb_transmission),
      'test' => %w(rollbar rack_attack influxdb_transmission),
      'develop' => [],
      'staging' => [],
      'production' => []
    }.freeze

    class << self
      def integration_enabled?(integration_name)
        case ENV["#{integration_name.upcase}_ENABLED"]
        when 'true'
          true
        when 'false'
          false
        else # default
          !DISABLED_INTEGRATIONS_BY_ENV[environment].include?(integration_name)
        end
      end

      private

      def environment
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      end
    end
  end
end
