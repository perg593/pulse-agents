require "qrvey_api"

QrveyAPI.configure do |config|
  config.api_key = Rails.application.credentials.qrvey[:api_key]
end
