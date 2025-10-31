# frozen_string_literal: true

module GammaClient
  module HTTP
    class GammaError < StandardError
      attr_reader :status_code, :message

      def initialize(message, status_code = nil)
        @message = message
        @status_code = status_code
        super(message)
      end
    end

    def self.json_post(url, body, logger)
      response = RestClient::Request.execute(
        method: :post,
        url: url,
        payload: body.to_json,
        headers: headers,
        log: logger
      )

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      handle_error_response(e, logger)
    rescue SocketError => e
      logger.error("Gamma API connection error: #{e.message}")
      nil
    end

    def self.json_get(url, logger)
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        headers: headers,
        log: logger
      )

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      handle_error_response(e, logger)
    rescue SocketError => e
      logger.error("Gamma API connection error: #{e.message}")
      nil
    end

    def self.handle_error_response(exception, logger)
      status_code = exception.http_code
      error_message = extract_error_message(exception.response.body)

      logger.error("Gamma API error (#{status_code}): #{error_message}")

      raise_error_for_status_code(status_code, error_message)
    end

    def self.extract_error_message(response_body)
      json_body = JSON.parse(response_body)
      json_body["message"] || "Unknown error"
    rescue JSON::ParserError
      response_body || "Unknown error"
    end

    def self.raise_error_for_status_code(status_code, error_message)
      error_map = {
        400 => "Bad Request: #{error_message}",
        401 => "Unauthorized: Invalid API key",
        404 => "Not Found: #{error_message}",
        422 => "Generation failed: #{error_message}",
        429 => "Rate limit exceeded. Please retry later.",
        500 => "Internal server error. Please contact support.",
        502 => "Bad gateway. Please try again."
      }

      error_text = error_map[status_code] || "Unexpected error (#{status_code}): #{error_message}"
      raise GammaError.new(error_text, status_code)
    end

    def self.headers
      {
        'X-API-KEY': GammaAPI.configuration.api_key,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    end
  end
end
