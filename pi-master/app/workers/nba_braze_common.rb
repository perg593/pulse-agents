# frozen_string_literal: true

module NBABrazeCommon
  include Common

  # This is not secret
  ENDPOINT = 'https://rest.iad-03.braze.com/users/track'

  def self.valid_email_address?(email_address)
    (email_address =~ URI::MailTo::EMAIL_REGEXP).present?
  end

  def self.clean_email_address(email_address)
    clean_version = email_address.dup

    clean_version.strip!
    clean_version.gsub!(/ /, "+") # To permit gmail aliases like jonathan+pi@ekohe.com

    clean_version
  end

  def send_to_braze(payload)
    if Rails.env.development?
      tagged_logger.info("Skipping delivery to braze for env: #{Rails.env}")
      return ["success", nil]
    end

    res = Retryable.with_retry(interval: 1, logger: tagged_logger) do
      RestClient::Request.execute(method: :post, url: ENDPOINT, payload: payload, headers: header, log: tagged_logger)
    end

    body = JSON.parse(res.body)

    [body['message'], body['error']]
  end

  private

  def header
    # TODO: Something other that this. Special routes for testing hurts test coverage
    if Rails.env.test?
      { Authorization: "Bearer TEST_CREDENTIALS" }
    else
      { Authorization: "Bearer #{Rails.application.credentials.nba[:braze][braze_app.to_sym][:api_key]}" }
    end
  end
end
