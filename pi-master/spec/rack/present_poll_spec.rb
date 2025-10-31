# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "present_poll_schema")

describe Rack::PresentPoll do
  before do
    Account.delete_all
    Survey.delete_all
    Trigger.delete_all
    Device.delete_all
    Submission.delete_all
    Sidekiq::Queue.new.clear
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  it_behaves_like "rack parameter verifier", [:identifier, :device_type, :callback, :udid], "/surveys/42/poll" do
    let(:optional_defaults) { { device_type: "desktop" } }
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      survey = create(:survey, account: account, poll_enabled: true)

      basic_poll_call(account, survey, survey.questions.first.id)
    end
  end

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      survey = create(:survey, account: create(:account), poll_enabled: true)

      basic_poll_call(create(:account), survey, survey.questions.first.id, parameters: { identifier: identifier_param })
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account, poll_enabled: true)

      basic_poll_call(account, survey, survey.questions.first.id,
                      parameters: { preview_mode: preview_mode },
                      headers: { X_REAL_IP: "192.168.0.1" })
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      expect(parse_json_response(response.body)["survey"]).not_to be_nil
    end
  end

  describe '/surveys/:id/poll' do
    describe "response validation" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, poll_enabled: true) }

      before do
        @response = basic_poll_call(account, survey, survey.questions.first.id)
      end

      context "when successful" do
        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::PresentPoll::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        before do
          @response = basic_poll_call(account, survey, survey.questions.first.id, parameters: { identifier: nil })
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::PresentPoll::ErrorResponseSchema, @response.body
        end
      end
    end

    it "returns polls" do
      account = create(:account)
      survey = create(:survey, poll_enabled: true)
      survey.account = account
      survey.save
      survey.reload
      response = basic_poll_call(account, survey, survey.questions.first.id, parameters: { udid: "00000000-0000-4000-f000-000000000000" })
      json_response = parse_json_response(response.body)

      possible_answers = survey.questions.first.possible_answers.sort_by_position
      expect(json_response['results'].count).to eq possible_answers.count
      expect(json_response['results'][0]['id']).to eq possible_answers[0].id.to_s
      expect(json_response['results'][0]['content']).to eq possible_answers[0].content
      expect(json_response['results'][0]['count']).to eq 0
      expect(json_response['results'][1]['id']).to eq possible_answers[1].id.to_s
      expect(json_response['results'][1]['content']).to eq possible_answers[1].content
      expect(json_response['results'][1]['count']).to eq 0
    end

    it "returns survey" do
      account = create(:account)
      survey = create(:survey, poll_enabled: true)
      survey.account = account
      survey.save
      survey.reload
      response = basic_poll_call(account, survey, survey.questions.first.id, parameters: { udid: "00000000-0000-4000-f000-000000000000" })
      json_response = parse_json_response(response.body)

      expect(json_response['survey']['id']).to eq survey.id
      expect(json_response["survey"]["name"]).to eq(survey.name)
    end

    it "returns question" do
      account = create(:account)
      survey = create(:survey, poll_enabled: true)
      survey.account = account
      survey.save
      survey.reload
      response = basic_poll_call(account, survey, survey.questions.first.id, parameters: { udid: "00000000-0000-4000-f000-000000000000" })
      json_response = parse_json_response(response.body)

      expect(json_response['question']['id']).to eq survey.questions.first.id.to_s
      expect(json_response['question']['content']).to eq survey.questions.first.content
      expect(json_response['question']['question_type']).to eq survey.questions.first.question_type_before_type_cast.to_s
    end

    it "does not return question or results if not from account" do
      account = create(:account)
      survey = create(:survey, poll_enabled: true)
      survey.account = account
      survey.save
      survey.reload
      question = create(:question)

      response = basic_poll_call(account, survey, question.id, parameters: { udid: "00000000-0000-4000-f000-000000000000" })
      json_response = parse_json_response(response.body)

      expect(json_response['question']).to be_nil
      expect(json_response['results']).to be_nil
    end

    it "does not return survey if not from account" do
      account = create(:account)
      survey = create(:survey, poll_enabled: true)
      other_survey = create(:survey, poll_enabled: true)
      survey.account = account
      survey.save
      survey.reload

      response = basic_poll_call(account, other_survey, survey.questions.first.id, parameters: { udid: "00000000-0000-4000-f000-000000000000" })

      expect(response.code).to eq "403"
      expect(response.body).to eq "Error: Poll not enabled for this survey"
    end

    context "when poll_enabled is false" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, poll_enabled: false) }

      it "returns 403 Forbidden" do
        response = basic_poll_call(account, survey, survey.questions.first.id)

        expect(response.code).to eq "403"
        expect(response.body).to eq "Error: Poll not enabled for this survey"
      end
    end

    context "when poll_enabled is true" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, poll_enabled: true) }

      it "returns 200 OK with poll results" do
        response = basic_poll_call(account, survey, survey.questions.first.id)

        expect(response.code).to eq "200"
        json_response = parse_json_response(response.body)
        expect(json_response['survey']).not_to be_nil
        expect(json_response['question']).not_to be_nil
        expect(json_response['results']).not_to be_nil
      end
    end

    context "when survey has limiting conditions but poll_enabled is true" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, poll_enabled: true) }

      shared_examples "returns poll results" do
        it "returns poll results" do
          response = basic_poll_call(account, survey, survey.questions.first.id)

          expect(response.code).to eq "200"
          json_response = parse_json_response(response.body)
          expect(json_response['survey']).not_to be_nil
          expect(json_response['question']).not_to be_nil
          expect(json_response['results']).not_to be_nil
        end
      end

      context "when survey status is draft (0)" do
        before do
          survey.update(status: 0)
        end

        include_examples "returns poll results"
      end

      context "when survey starts_at is in the future" do
        before do
          survey.update(starts_at: 1.day.from_now)
        end

        include_examples "returns poll results"
      end

      context "when survey ends_at is in the past" do
        before do
          survey.update(ends_at: 1.day.ago)
        end

        include_examples "returns poll results"
      end

      context "when survey has stop_showing_without_answer enabled" do
        before do
          survey.update(stop_showing_without_answer: true)
        end

        include_examples "returns poll results"
      end

      context "when user has previously closed the survey" do
        before do
          survey.update(stop_showing_without_answer: true)
          device = create(:device, udid: udid)
          create(:submission, survey: survey, device: device, closed_by_user: true)
        end

        include_examples "returns poll results"
      end

      context "when survey is paused (status 2)" do
        before do
          survey.update(status: 2)
        end

        include_examples "returns poll results"
      end

      context "when survey is complete (status 3)" do
        before do
          survey.update(status: 3)
        end

        include_examples "returns poll results"
      end

      context "when survey is archived (status 4)" do
        before do
          survey.update(status: 4)
        end

        include_examples "returns poll results"
      end

      context "when survey has sample_rate less than 100" do
        before do
          survey.update(sample_rate: 50)
        end

        include_examples "returns poll results"
      end

      context "when device type is disabled for the survey" do
        before do
          survey.update(desktop_enabled: false)
        end

        include_examples "returns poll results"
      end

      context "when multiple limiting conditions are combined" do
        before do
          survey.update(
            status: 0, # draft
            starts_at: 1.day.from_now,
            ends_at: 1.day.ago,
            stop_showing_without_answer: true,
            sample_rate: 25,
            desktop_enabled: false
          )
        end

        include_examples "returns poll results"
      end
    end
  end

  describe 'background' do
    it 'serves the survey background image with https' do
      account = create(:account)
      question = create(:question)
      background_image = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")
      survey = create(:survey, background: background_image, poll_enabled: true, account: account)

      response = basic_poll_call(account, survey, question.id)
      json_response = parse_json_response(response.body)

      expect(json_response['survey']['background']).to include('https')
    end
  end

  # Calls the present poll endpoint with the required parameters and headers
  def basic_poll_call(account, survey, question_id, parameters: {}, headers: {})
    query = {
      callback: callback,
      udid: udid,
      device_type: "desktop",
      identifier: account.identifier,
      question_id: question_id
    }.merge(parameters).to_query

    headers = { Referer: "http://localhost:3000" }.merge(headers)

    rack_app("/surveys/#{survey.id}/poll?#{query}", headers)
  end
end
