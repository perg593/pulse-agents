# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "track_event_schema")

describe Rack::TrackEvent do
  before do
    Sidekiq::Queue.new.clear
  end

  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  it_behaves_like "rack parameter verifier", [:identifier, :event_name, :event_properties], "/track_event"

  describe '/track_event' do
    let(:event_name) { 'test_event' }
    let(:event_properties) { { test: 1, event: 2 }.to_json }
    let(:url) { 'https://track_event.com' }

    let(:track_event_url) { "/track_event?identifier=#{account.identifier}&udid=#{udid}&event_name=#{event_name}&event_properties=#{event_properties}&url=#{url}&callback=#{callback}&" }

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        query = {
          udid: udid,
          identifier: account.identifier,
          event_name: event_name,
          event_properties: event_properties,
          url: url
        }.to_query

        rack_app("/track_event?#{query}")
      end
    end

    it_behaves_like "accounts.ips_to_block-based request blocker" do
      def make_call(preview_mode)
        query = {
          udid: udid,
          identifier: account.identifier,
          event_name: event_name,
          event_properties: event_properties,
          url: url,
          preview_mode: preview_mode
        }.to_query

        url = "/track_event?#{query}"

        headers = { X_REAL_IP: "192.168.0.1" }

        rack_app(url, headers)
      end

      def non_blocked_response(response)
        expect(response.code).to eq "200"
        assert_valid_schema RackSchemas::TrackEvent::SuccessfulResponseSchema, response.body
      end
    end

    it 'queues CreatePageEventWorker job' do
      response = rack_app(track_event_url)

      expect(Sidekiq::Queue.new.first['class']).to eq 'CreatePageEventWorker'
      expect(Sidekiq::Queue.new.first['args']).to eq [event_name, event_properties, account.identifier, udid, url]
      assert_valid_schema RackSchemas::TrackEvent::SuccessfulResponseSchema, response.body
    end

    describe 'validations' do
      context 'when identifier is blank' do
        it 'does not queue CreatePageEventWorker job' do
          account.identifier = nil

          response = rack_app(track_event_url)

          expect(Sidekiq::Queue.new.count).to eq 0
          expect(response.body).to include "'identifier' missing"
          assert_valid_schema RackSchemas::TrackEvent::ErrorResponseSchema, response.body
        end
      end

      context 'when event_name is blank' do
        let(:event_name) { nil }

        it 'does not queue CreatePageEventWorker job' do
          response = rack_app(track_event_url)

          expect(Sidekiq::Queue.new.count).to eq 0
          expect(response.body).to include "'event_name' blank"
          assert_valid_schema RackSchemas::TrackEvent::ErrorResponseSchema, response.body
        end
      end

      context 'when event_properties is blank' do
        let(:event_properties) { nil }

        it 'does not queue CreatePageEventWorker job' do
          response = rack_app(track_event_url)

          expect(Sidekiq::Queue.new.count).to eq 0
          expect(response.body).to include "'event_properties' blank"
          assert_valid_schema RackSchemas::TrackEvent::ErrorResponseSchema, response.body
        end
      end

      context 'when url is blank' do
        let(:url) { nil }

        it 'does not queue CreatePageEventWorker job' do
          response = rack_app(track_event_url)

          expect(Sidekiq::Queue.new.count).to eq 0
          expect(response.body).to include "URL not captured"
          assert_valid_schema RackSchemas::TrackEvent::ErrorResponseSchema, response.body
        end
      end
    end
  end
end
