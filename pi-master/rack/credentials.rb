# frozen_string_literal: true

require 'active_support/core_ext/hash/keys' # The encryption module uses the "deep_symbolize_keys" method
require 'active_support/encrypted_configuration'

module Rack
  module Credentials
    class << self
      def credentials
        ActiveSupport::EncryptedConfiguration.new(
          config_path: ::File.join(::File.dirname(__FILE__), '..', 'config', 'credentials', "#{env}.yml.enc"),
          key_path: ::File.join(::File.dirname(__FILE__), '..', 'config', 'credentials', "#{env}.key"),
          env_key: "RAILS_MASTER_KEY",
          raise_if_missing_key: false
        )
      end

      private

      def env
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      end
    end
  end
end
