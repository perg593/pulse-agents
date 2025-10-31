# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "submissions_schema")

describe Rack::Submissions do
  before do
    Sidekiq::Queue.new.clear
    Sidekiq::ScheduledSet.new.clear
    Device.delete_all
    Submission.delete_all
    Answer.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  describe '/submissions/:id/close/' do
    describe "response validation" do
      let(:account) { create(:account) }

      before do
        survey = create(:survey, account: account)
        @submission_udid = create(:submission, survey: survey).udid

        headers = { Referer: "http://localhost:3000" }

        @response = rack_app(url, headers)
      end

      context "when successful" do
        let(:url) { "/submissions/#{@submission_udid}/close" }

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Submissions::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:url) { "/submissions/undefined/close" }

        it "returns code 400" do
          expect(@response.code).to eq "404"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Submissions::ErrorResponseSchema, @response.body
        end
      end
    end

    it "enqueues UpdateCloseByUserWorker" do
      submission_udid = create(:submission, survey: create(:survey)).udid

      expect(rack_app("/submissions/#{submission_udid}/close?callback=#{callback}").code).to eq('200')

      expect(Sidekiq::Queue.new.size).to eq(1)
      expect(Sidekiq::Queue.new.first.item['class']).to eq('UpdateCloseByUserWorker')
      expect(Sidekiq::Queue.new.first.item['args']).to eq([submission_udid])
    end
  end

  describe 'submissions/:id/viewed_at' do
    describe "response validation" do
      let(:account) { create(:account) }
      let(:query) { { callback: callback, viewed_at: Time.current }.to_query }

      before do
        create(:survey, account: account)

        headers = { Referer: "http://localhost:3000" }

        @response = rack_app(url, headers)
      end

      context "when successful" do
        let(:url) { "/submissions/#{udid}/viewed_at?#{query}" }

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Submissions::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:url) { "/submissions/#{udid}/viewed_at?callback=#{callback}" }

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Submissions::ErrorResponseSchema, @response.body
        end
      end
    end

    it_behaves_like "rack parameter verifier", [:viewed_at], "/submissions/00000000-0000-4000-f000-000000000001/viewed_at"

    it "verifies submission_udid" do
      invalid_udid = "undefined"

      query = { viewed_at: Time.current }.to_query

      response = rack_app("/submissions/#{invalid_udid}/viewed_at?#{query}")

      expect(response.code).to eq("404")
      expect(response.body).to eq("Not found")
    end

    it 'verifies viewed_at' do
      invalid_viewed_at = '123456789'
      res = rack_app("/submissions/#{udid}/viewed_at?callback=#{callback}&viewed_at=#{invalid_viewed_at}")
      expect(res.code).to eq('400')
      expect(res.body).to eq("Parameter 'viewed_at' invalid")
    end

    it 'queues UpdateSubmissionViewedAtWorker' do
      viewed_at = Time.current.to_s
      query = { callback: callback, viewed_at: viewed_at }.to_query
      res = rack_app("/submissions/#{udid}/viewed_at?#{query}")
      expect(res.code).to eq('200')

      queue = Sidekiq::Queue.new
      expect(queue.size).to eq(1)
      expect(queue.first.item['class']).to eq('UpdateSubmissionViewedAtWorker')
      expect(queue.first.item['args']).to contain_exactly(udid, viewed_at)
    end
  end
end
