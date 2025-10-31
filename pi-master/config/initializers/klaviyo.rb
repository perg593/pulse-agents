KlaviyoAPI.configure do |config|
  config.api_key['Klaviyo-API-Key'] = "Klaviyo-API-Key #{Rails.application.credentials.klaviyo[:api_key]}"
  config.max_retries = 5
  config.max_delay = 60
end
