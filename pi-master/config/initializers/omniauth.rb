Rails.application.config.middleware.use OmniAuth::Builder do
  OmniAuth.config.logger = Rails.logger # https://github.com/omniauth/omniauth#logging

  google_credentials = Rails.application.credentials.google_oauth2

  if Rails.env.test?
    provider :developer
  else
    provider :google_oauth2, google_credentials[:client_id], google_credentials[:secret]

    OmniAuth::MultiProvider.register(self,
                                     provider_name: :saml,
                                     identity_provider_id_regex: /[\w|-]+/,
                                     path_prefix: '/auth/saml',
                                     callback_suffix: 'callback',
                                     allowed_clock_drift: 5.seconds) do |identity_provider_id, rack_env|
                                       if identity_provider_id == "pi_google_test"
                                         Account.static_idp_config('google_test')
                                       elsif identity_provider_id == '906aefe9-76a7-4f65-b82d-5ec20775d5aa'
                                         Account.static_idp_config('comcast')
                                       else
                                         raise ArgumentError, "Identity provider #{identity_provider_id} not found"
                                       end
                                     end
  end
end
