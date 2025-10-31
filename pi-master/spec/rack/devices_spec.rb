# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "devices_schema")

describe Rack::Devices do
  before do
    Sidekiq::Queue.new.clear
  end

  let(:account) { create(:account) }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      rack_app("/devices/#{udid}/set_data?&gender=male&callback=#{callback}#{identifier_param}")
    end
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      rack_app("/devices/#{udid}/set_data?&gender=male&callback=#{callback}&identifier=#{account.identifier}")
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier], "/devices/00000000-0000-4000-f000-000000000001/set_data"

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      create(:survey, account: account)

      headers = { X_REAL_IP: "192.168.0.1" }

      query = {
        identifier: account.identifier,
        callback: callback,
        preview_mode: preview_mode
      }.to_query

      url = "/devices/#{udid}/set_data?#{query}"

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::Devices::SuccessfulResponseSchema, response.body
    end
  end

  describe '/devices/:udid/set_data/' do
    describe "response validation" do
      context "when successful" do
        before do
          @response = rack_app("/devices/#{udid}/set_data?identifier=#{account.identifier}")
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Devices::SuccessfulResponseSchema, @response.body
        end
      end

      context "when unsuccessful" do
        before do
          @response = rack_app("/devices/#{udid}/set_data?")
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Devices::ErrorResponseSchema, @response.body
        end
      end
    end

    it 'enqueues SetDeviceDataWorker' do
      response = rack_app("/devices/#{udid}/set_data?identifier=#{account.identifier}&test=data&callback=#{callback}")

      expect(response.code).to eq '200'
      expect(Sidekiq::Queue.new.size).to eq(1)
      expect(Sidekiq::Queue.new.first.item['class']).to eq('SetDeviceDataWorker')
      expect(Sidekiq::Queue.new.first['args']).to eq [udid, {"identifier" => account.identifier, "test" => "data"}]
    end
  end
end
