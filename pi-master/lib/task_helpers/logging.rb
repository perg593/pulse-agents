# frozen_string_literal: true

module Logging
  def log(msg)
    @logger.info "[#{timestamp}] #{msg}"
  end

  def timestamp
    Time.now.strftime('%Y/%m/%d - %H:%M:%S')
  end

  # Name the log file after the task you're running. E.g. "rake add_surveys" will create "log/add_surveys.log"
  def tagged_logger
    @tagged_logger ||= ActiveSupport::TaggedLogging.new(Logger.new(ENV["STD_OUT"] ? $stdout : "log/#{ARGV[0]}.log"))
  end
end
