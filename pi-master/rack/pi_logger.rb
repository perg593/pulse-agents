# frozen_string_literal: true

require 'yaml'
require File.join(File.dirname(__FILE__), 'credentials')

module Rack
  module PiLogger
    LOG_FILE = ENV["LOG_FILE"] || ::File.join(::File.dirname(__FILE__), '..', 'log', 'serving.log')
    ENVIRONMENT = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    MAX_LEVEL = Credentials.credentials[:logger_level]

    LOG_LEVEL_INFO = "INFO"
    LOG_LEVEL_DEBUG = "DEBUG"
    LOG_LEVELS = [LOG_LEVEL_INFO, LOG_LEVEL_DEBUG].freeze

    # rubocop:disable Lint/ConstantDefinitionInBlock
    Signal.trap('USR2') do # Switch MAX_LEVEL
      MAX_LEVEL =
        if MAX_LEVEL == 'INFO'
          'DEBUG'
        else
          'INFO'
        end

      puts "LOG LEVEL NOW SET AS #{MAX_LEVEL}"
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock

    # Method to log messages to the log file or STDOUT in dev environment
    def log(message, level = 'INFO')
      @log_file = ::File.new(LOG_FILE, 'a+') if @log_file.nil?
      puts message if @environment == "development"

      if save_message_in_file?(level)
        @log_file << "#{Time.now.strftime('%Y/%m/%d - %H:%M:%S')} - "
        @log_file << message
        @log_file << "\n"
        @log_file.flush
      end

      message
    end

    def save_message_in_file?(level)
      max_level = MAX_LEVEL || LOG_LEVEL_INFO

      case max_level
      when LOG_LEVEL_INFO
        level == LOG_LEVEL_INFO
      else # DEBUG
        true
      end
    end

    def report_to_rollbar(message, options = {})
      log("#{message} - #{options}")
      Rollbar.error(message, options)
    end
  end
end
