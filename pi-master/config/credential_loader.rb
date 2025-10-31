# frozen_string_literal: true

require "active_support/encrypted_configuration"
require "active_support/core_ext/hash/keys"

# https://stackoverflow.com/a/72671661/858295
module CredentialLoader
  def read_credentials(environment:)
    YAML.load(
      ActiveSupport::EncryptedConfiguration.new(
        config_path: "config/credentials/#{environment}.yml.enc",
        key_path: "config/credentials/#{environment}.key",
        env_key: environment.to_s,
        raise_if_missing_key: true
      ).read
    )
  end
end
