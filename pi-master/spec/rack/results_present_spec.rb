# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "present_results_schema")

describe Rack::Results do
  let(:endpoint) { "/present_results" }

  it_behaves_like "rack parameter verifier", [:identifier, :submission_udid], "/present_results"

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      survey = create(:survey, account: account, poll_enabled: true)
      submission = create(:submission, survey: survey)
      create(:answer, question: survey.questions.first, submission: submission)

      query_parameters = {
        identifier: account.identifier,
        submission_udid: submission.udid
      }

      url = "#{endpoint}?#{query_parameters.to_query}"

      rack_app(url)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account, poll_enabled: false)
      submission = create(:submission, survey: survey)
      create(:answer, question: survey.questions.first, submission: submission)

      query_parameters = {
        identifier: account.identifier,
        submission_udid: submission.udid,
        preview_mode: preview_mode
      }

      url = "#{endpoint}?#{query_parameters.to_query}"

      headers = { X_REAL_IP: "192.168.0.1" }

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::PresentResults::ThankYouResponseSchema, parse_json_response(response.body)
    end
  end

  describe "poll vs thank_you" do
    let(:survey) { create(:survey, account: create(:account), poll_enabled: poll_enabled) }

    before do
      submission = create(:submission, survey: survey)
      @answer = create(:answer, question: survey.questions.first, submission: submission)

      query = {
        identifier: survey.account.identifier,
        submission_udid: submission.udid
      }.to_query

      url = "#{endpoint}?#{query}"

      @response = rack_app(url)
    end

    context "when surveys.poll_enabled is false" do
      let(:poll_enabled) { false }

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::PresentResults::ThankYouResponseSchema, parse_json_response(@response.body)
      end

      it "returns the expected values" do
        expect(parse_json_response(@response.body)["thank_you"]).to eq survey.thank_you
      end
    end

    context "when surveys.poll_enabled is true" do
      let(:poll_enabled) { true }

      before do
        @values = parse_json_response(@response.body)
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::PresentResults::ThankYouAndPollResponseSchema, parse_json_response(@response.body)
      end

      # In no particular order...
      it "returns the type of one of the questions" do
        question_with_answers = @answer.possible_answer.question

        expect(@values["question_type"]).to eq(Question.question_types[question_with_answers.question_type].to_s)
      end

      it "returns the content of one of the questions" do
        question_with_answers = @answer.possible_answer.question

        expect(@values["content"]).to eq question_with_answers.content
      end

      it "returns the IDs of all answers for this question and submission" do
        expect(@values["answers_via_checkbox"]).to contain_exactly(@answer.id.to_s)
      end

      it "returns the poll results" do
        question_with_answers = @answer.question

        # one for each possible answer in question with answers
        # TODO: Confirm only single_choice_question and multiple_choices_question show up
        # TODO: Ask whether slider_question should appear (code says no, but we probably just forgot about this endpoint)
        expect(@values["poll"].count).to eq question_with_answers.possible_answers.count

        @values["poll"].each_with_index do |poll_result, index|
          possible_answer = question_with_answers.possible_answers.sort_by_position[index]

          expect(poll_result["id"]).to eq possible_answer.id.to_s
          expect(poll_result["content"]).to eq possible_answer.content
          expect(poll_result["count"]).to eq possible_answer.answers.count
        end
      end
    end
  end
end
