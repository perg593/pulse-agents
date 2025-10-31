require "gamma_api"

GammaAPI.configure do |config|
  config.api_key = Rails.application.credentials.gamma[:api_key]
end
