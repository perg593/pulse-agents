# frozen_string_literal: true

module QrveyClient
  module HTTP
    class QrveyError < StandardError
    end

    def self.json_delete(url, logger)
      response = RestClient::Request.execute(method: :delete, url: url, headers: headers, log: logger)

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      json_body = JSON.parse(e.response.body)
      error_messages = json_body["errors"].map { |errors| errors["message"] }.join(",")

      raise QrveyError, error_messages
    rescue SocketError => _e
      nil
    end

    def self.post(url, body, logger)
      RestClient::Request.execute(method: :post, url: url, payload: body.to_json, headers: headers, log: logger)
    rescue RestClient::ExceptionWithResponse => e
      json_body = JSON.parse(e.response.body)
      error_messages = json_body["errors"].map { |errors| errors["message"] }.join(",")

      raise QrveyError, error_messages
    rescue SocketError => _e
      nil
    end

    def self.put(url, body, logger)
      RestClient::Request.execute(method: :put, url: url, payload: body.to_json, headers: headers, log: logger)
    rescue RestClient::ExceptionWithResponse => e
      json_body = JSON.parse(e.response.body)
      error_messages = json_body["errors"].map { |errors| errors["message"] }.join(",")

      raise QrveyError, error_messages
    end

    def self.patch(url, body, logger)
      RestClient::Request.execute(method: :patch, url: url, payload: body.to_json, headers: headers, log: logger)
    rescue RestClient::ExceptionWithResponse => e
      json_body = JSON.parse(e.response.body)
      error_messages = json_body["errors"].map { |errors| errors["message"] }.join(",")

      raise QrveyError, error_messages
    end

    def self.json_patch(url, body, logger)
      response = patch(url, body, logger)

      JSON.parse(response.body) if response
    end

    def self.json_put(url, body, logger)
      response = put(url, body, logger)

      JSON.parse(response.body) if response
    end

    def self.json_post(url, body, logger)
      response = post(url, body, logger)

      JSON.parse(response.body) if response
    rescue SocketError => _e
      nil
    end

    def self.json_get(url, logger)
      response = RestClient::Request.execute(method: :get, url: url, headers: headers, log: logger)

      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      json_body = JSON.parse(e.response.body)
      error_messages = json_body["errors"].map { |errors| errors["message"] }.join(",")

      raise QrveyError, error_messages
    rescue SocketError => _e
      nil
    end

    def self.headers
      {
        'x-api-key': QrveyAPI.configuration.api_key,
        'Content-Type': 'application/json'
      }
    end
  end
end
