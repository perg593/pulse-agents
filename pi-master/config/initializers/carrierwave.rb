CarrierWave.configure do |config|
  # Make sure the test environment uses the local file system, not AWS
  if Rails.env.test?
    config.enable_processing = false
    config.asset_host = ActionController::Base.asset_host
  else
    config.fog_provider = 'fog/aws'
    aws_credentials = Rails.application.credentials.aws

    # TODO: Regenerate and encrypt these in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2146
    config.fog_credentials = {
      provider:              'AWS',
      aws_access_key_id:     aws_credentials[:access_key_id],
      aws_secret_access_key: aws_credentials[:secret_access_key],
      region:                'us-west-2',
    }

    config.fog_directory  = 'pi-custom-content'
    config.asset_host = 'https://cdn.pulseinsights.com'
    config.permissions = 0666
    config.directory_permissions = 0777
  end
end
