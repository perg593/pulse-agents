# frozen_string_literal: true
module Saml
  def self.create_saml_auth_request(idp_config)
    saml_auth_request = OneLogin::RubySaml::Authrequest.new
    saml_auth_request.create(saml_settings(idp_config))
  end

  def self.saml_settings(idp_config)
    settings = OneLogin::RubySaml::Settings.new

    settings.assertion_consumer_service_url = idp_config[:assertion_consumer_service_url]
    settings.sp_entity_id = idp_config[:issuer]
    settings.idp_entity_id = idp_config[:idp_entity_id]
    settings.idp_sso_service_url = idp_config[:idp_sso_service_url]
    settings.idp_cert = idp_config[:idp_cert]
    settings.idp_sso_service_binding = idp_config[:idp_sso_service_binding]
    settings.name_identifier_format = idp_config[:name_identifier_format]

    settings
  end
end
