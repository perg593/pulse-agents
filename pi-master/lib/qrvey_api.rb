# frozen_string_literal: true

module QrveyAPI
  class Configuration
    attr_writer :api_key

    def initialize
      @api_key = nil
    end

    def api_key
      return @api_key if @api_key
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= QrveyAPI::Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
