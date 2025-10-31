# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Rack::IntegrationSwitch do
  environments = %w(development test develop staging production)

  shared_examples 'integration switch behavior' do |integration_name|
    subject { described_class.integration_enabled?(integration_name) }

    let(:env_var_name) { "#{integration_name.upcase}_ENABLED" }

    describe "#{integration_name} integration" do
      [true, false].each do |boolean|
        context "when the env var is '#{boolean}'" do
          before { ENV[env_var_name] = boolean.to_s }
          after { ENV.delete(env_var_name) }

          environments.each do |env|
            context "with #{env} environment" do
              before { ENV['RACK_ENV'] = env }
              after { ENV.delete('RACK_ENV') }

              it { is_expected.to be boolean }
            end
          end
        end
      end

      context "when the env var is not set to 'true' or 'false'" do
        environments.each do |env|
          context "with #{env} environment" do
            before { ENV['RACK_ENV'] = env }
            after { ENV.delete('RACK_ENV') }

            let(:default_value) do
              disabled_integrations = described_class::DISABLED_INTEGRATIONS_BY_ENV[env]
              !disabled_integrations.include?(integration_name)
            end

            it { is_expected.to eq(default_value) }
          end
        end
      end
    end
  end

  describe '#integration_enabled?' do
    include_examples 'integration switch behavior', 'rollbar'
    include_examples 'integration switch behavior', 'rack_attack'
    include_examples 'integration switch behavior', 'influxdb_transmission'
  end
end
