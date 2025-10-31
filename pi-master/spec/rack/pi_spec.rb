# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "heartbeat_schema")

describe Rack::Pi do
  describe 'endpoints' do
    let(:url) { nil }

    before do
      @response = rack_app(url)
    end

    describe "/heartbeat" do
      let(:url) { "/heartbeat" }

      it "returns a 200" do
        expect(@response.code).to eq("200")
      end

      it "detects pulse!" do
        expect(@response.body).to eq('Pulse detected!')
      end

      it "matches the expected schema" do
        assert_valid_schema RackSchemas::Heartbeat::SuccessfulResponseSchema, @response.body
      end
    end

    describe "/some_random_endpoint" do
      let(:url) { "/whatever" }

      it "anything random should return 404 not found" do
        expect(@response.code).to eq("404")
      end

      it "matches the expected schema" do
        assert_valid_schema RackSchemas::Heartbeat::ErrorResponseSchema, @response.body
      end
    end
  end

  describe 'ip blocking' do
    before :all do
      enable_rack_attack
      restart_rack_app
    end

    after :all do
      disable_rack_attack
      restart_rack_app
    end

    before do
      delete_rack_attack_cache
    end

    after do
      delete_rack_attack_cache
    end

    it 'blocks an ip after 100 requests within a day' do
      100.times { rack_app('/serve') }
      res = rack_app('/serve')
      expect_ip_to_be_blocked(res)
      expect_no_server_error(res)
    end

    it 'does not block an ip unless more than 100 requests are made within a day' do
      5.times { rack_app('/serve') }
      res = rack_app('/serve')
      expect_ip_not_to_be_blocked(res)
      expect_no_server_error(res)
    end

    it "allows a blocked ip address that is on the referers whitelist/safelist" do
      good_referer = "chat.benjaminmoore.com"
      100.times { rack_app('/serve', "Referer" => good_referer) }
      res = rack_app('/serve', "Referer" => good_referer)
      expect_ip_not_to_be_blocked(res)
      expect_no_server_error(res)
    end

    it "allows a specific blocked ip address that is on the ip address whitelist/safelist" do
      good_ip = "157.49.229.64" # rack/config.ru
      100.times { rack_app('/serve', "X-Forwarded-For" => good_ip) }
      res = rack_app('/serve', "X-Forwarded-For" => good_ip)
      expect_ip_not_to_be_blocked(res)
      expect_no_server_error(res)
    end

    describe "native mobile app" do
      let(:request_uri) { "/serve?device_type=native_mobile" }

      it "allows 500 requests from the native mobile app" do
        499.times { rack_app(request_uri) }
        response = rack_app(request_uri)

        expect_ip_not_to_be_blocked(response)
        expect_no_server_error(response)
      end

      it "blocks an ip after 500 requests within a day" do
        500.times { rack_app(request_uri) }
        response = rack_app(request_uri)

        expect_ip_to_be_blocked(response)
        expect_no_server_error(response)
      end
    end

    describe "Zscaler IP range" do
      let(:zscaler_ip) { "136.226.244.100" }

      it "allows 200 requests from Zscaler IP range" do
        199.times { rack_app('/serve', "X-Forwarded-For" => zscaler_ip) }
        response = rack_app('/serve', "X-Forwarded-For" => zscaler_ip)

        expect_ip_not_to_be_blocked(response)
        expect_no_server_error(response)
      end

      it "blocks an ip after 200 requests within a day" do
        200.times { rack_app('/serve', "X-Forwarded-For" => zscaler_ip) }
        response = rack_app('/serve', "X-Forwarded-For" => zscaler_ip)

        expect_ip_to_be_blocked(response)
        expect_no_server_error(response)
      end
    end

    it "allows a wildcard blocked ip address that is on the ip address whitelist/safelist" do
      good_ip = "216.165.126.1" # rack/config.ru
      100.times { rack_app('/serve', "X-Forwarded-For" => good_ip) }
      res = rack_app('/serve', "X-Forwarded-For" => good_ip)
      expect_ip_not_to_be_blocked(res)
      expect_no_server_error(res)
    end

=begin
    # Expiry is set to each key inside Redis, so fixing time inside Rails doesn't set up a working test environment
    # We could manually expire those keys, but that diminishes the whole point of these tests below...
    it 'does not block an ip after 100 requests if it has been a day since the first request' do
      100.times { rack_app('/serve') }
      travel_to 1.day.after

      res = rack_app('/serve')
      expect_ip_not_to_be_blocked(res)

      travel_back
    end

    it 'unblocks an ip after a day' do
      100.times { rack_app('/serve') }
      res = rack_app('/serve')
      expect_ip_to_be_blocked(res)
      travel_to 1.day.after

      res = rack_app('/serve')
      expect_ip_not_to_be_blocked(res)

      travel_back
    end
=end
    it 'does not block an ip that has been hitting /heartbeat' do
      100.times { rack_app('/heartbeat') }
      res = rack_app('/heartbeat')
      expect_ip_not_to_be_blocked(res)
    end

    def expect_no_server_error(response)
      expect(response.code).not_to eq '500'
    end

    def expect_ip_to_be_blocked(response)
      expect(response.code).to eq '403'
      expect(response.body).to include 'Forbidden'
    end

    def expect_ip_not_to_be_blocked(response)
      expect(response.code).not_to eq '403'
      expect(response.body).not_to include 'Forbidden'
    end
  end
end
