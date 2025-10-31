# frozen_string_literal: true
require 'spec_helper'

describe Common do
  include Rack::PiLogger
  include described_class

  describe "postgres_configuration" do
    context "when there is no proxy setting in database.yml" do
      it "returns conventional setting" do
        expect(postgres_configuration[:host]).to eq 'postgres'
      end
    end

    context "when there is proxy settings in database.yml" do
      it "returns master config with readonly option set to false" do
        expect(postgres_configuration(config_yml: custom_config_yml)[:host]).to eq 'master_host'
        expect(postgres_configuration(config_yml: custom_config_yml)[:port]).to eq 5433
      end

      it "returns slave config with readonly option set to true" do
        expect(postgres_configuration(config_yml: custom_config_yml, readonly: true)[:host]).to eq 'slave_host'
        expect(postgres_configuration(config_yml: custom_config_yml, readonly: true)[:port]).to eq 5433
      end
    end

    def custom_config_yml
      {
        'test' => {
          'makara' => {
            'connections' => [
              {
                'role' => 'master',
                'host' => 'master_host',
                'port' => 5433
              },
              {
                'role' => 'slave',
                'host' => 'slave_host',
                'port' => 5433
              }
            ]
          }
        }
      }
    end
  end
end
