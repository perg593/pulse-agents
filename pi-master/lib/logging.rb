# frozen_string_literal: true

module Logging
  def tagged_logger
    unless @tagged_logger
      namespaced_class_name = self.class.name.underscore
      filepath = "log/#{namespaced_class_name}.log"

      if namespaced_class_name.include?("/")
        directory = "log/#{namespaced_class_name.split("/")[0..-2].join("/")}"
        FileUtils.makedirs(directory) unless File.directory?(directory)
      end

      logger = Logger.new(filepath)
      logger.formatter = Logger::Formatter.new
      @tagged_logger = ActiveSupport::TaggedLogging.new(logger)
    end

    @tagged_logger
  end

  # For RestClient https://github.com/rest-client/rest-client/pull/375/files
  def @tagged_logger.<<(message)
    info message
  end
end
