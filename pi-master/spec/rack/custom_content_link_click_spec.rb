# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "custom_content_link_click_schema")

describe Rack::CustomContentLinkClick do
  before do
    Sidekiq::Queue.new.clear
  end

  it_behaves_like "rack parameter verifier", [:submission_udid, :question_id, :link_identifier], "/custom_content_link_click"

  describe '/custom_content_link_click' do
    let(:question) { create(:custom_content_question) }
    let(:submission) { create(:submission, udid: '00000000-0000-4000-f000-000000000001', survey: question.survey) }
    let(:link_identifier) { SecureRandom.uuid }
    let(:client_key) { 'null' }
    let(:custom_data) { 'undefined' }
    let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

    let(:custom_content_link_click_url) { "/custom_content_link_click?submission_udid=#{submission.udid}&question_id=#{question.id}&link_identifier=#{link_identifier}&client_key=#{client_key}&custom_data=#{custom_data}&callback=#{callback}" }

    context "when the call is valid" do
      before do
        @response = rack_app(custom_content_link_click_url)
      end

      it "queues a CreateCustomContentLinkClickWorker job" do
        expect(Sidekiq::Queue.new.first.item['class']).to eq 'CreateCustomContentLinkClickWorker'
      end

      it "provides the expected arguments to the job" do
        expect(Sidekiq::Queue.new.first['args']).to eq [submission.udid, question.id.to_s, link_identifier, client_key, custom_data]
      end

      it "returns 200" do
        expect(@response.code).to include "200"
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::CustomContentLinkClick::SuccessfulResponseSchema, @response.body
      end
    end

    describe 'validations' do
      context 'when submission_udid is blank' do
        before do
          submission.udid = nil
          @response = rack_app(custom_content_link_click_url)
        end

        it "does not queue a CreateCustomContentLinkClickWorker job" do
          expect(Sidekiq::Queue.new.count).to eq 0
        end

        it "returns 400" do
          expect(@response.code).to include "400"
        end

        it "returns an error message" do
          expect(@response.body).to include "'submission_udid' missing"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::CustomContentLinkClick::ErrorResponseSchema, @response.body
        end
      end

      context 'when question_id is blank' do
        before do
          question.id = nil
          @response = rack_app(custom_content_link_click_url)
        end

        it "does not queue a CreateCustomContentLinkClickWorker job" do
          expect(Sidekiq::Queue.new.count).to eq 0
        end

        it "returns 400" do
          expect(@response.code).to include "400"
        end

        it "returns an error message" do
          expect(@response.body).to include "'question_id' missing"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::CustomContentLinkClick::ErrorResponseSchema, @response.body
        end
      end

      context 'when link_identifier is blank' do
        let(:link_identifier) { nil }

        before do
          @response = rack_app(custom_content_link_click_url)
        end

        it "does not queue a CreateCustomContentLinkClickWorker job" do
          expect(Sidekiq::Queue.new.count).to eq 0
        end

        it "returns 400" do
          expect(@response.code).to include "400"
        end

        it "returns an error message" do
          expect(@response.body).to include "'link_identifier' missing"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::CustomContentLinkClick::ErrorResponseSchema, @response.body
        end
      end
    end
  end
end
