# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'pi_logger')
require 'sidekiq'
require 'sidekiq-failures'

module Rack
  module SidekiqInit
    def redis_connect!
      environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'

      database_yml = YAML.load_file(::File.join(::File.dirname(__FILE__), '..', 'config', 'database.yml'), aliases: true)[environment]

      if database_yml.nil?
        log "Error: No redis configuration for env #{environment}"
      else
        Sidekiq.failures_max_count = 5000

        Sidekiq.configure_server do |config|
          config.redis = { url: database_yml["redis"] }
        end

        Sidekiq.configure_client do |config|
          config.redis = { url: database_yml["redis"] }
        end
      end

      Sidekiq::Testing.inline! if environment == 'test' && ENV['SIDEKIQ_INLINE'] == 'true'

      log "Sidekiq initialized for env #{environment}"
    end

    def redis_heartbeat
      Sidekiq.redis(&:ping)
    end
  end
end
