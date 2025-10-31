# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "submissions_schema")

describe Rack::Submissions do
  before do
    Sidekiq::Queue.new.clear
    Device.delete_all
    Submission.delete_all
    Answer.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  describe '/submissions/:id/all_answers' do
    before do
      @account = create(:account)
      @survey = create(:survey)
      @survey.account = @account
      @survey.save
      @survey.reload
    end

    # Calls the endpoint with the required parameters and headers
    def basic_all_answers_call(account, submission_udid, answers, parameters: {}, headers: {})
      answers_json = answers.map do |answer|
        {
          question_id: answer.question.id,
          question_type: answer.question.question_type,
          answer: answer.possible_answer_id
        }
      end.to_json

      query = {
        identifier: account.identifier,
        answers: answers_json,
        allback: callback
      }.merge(parameters).to_query

      default_headers = { Referer: "http://localhost:3000" }

      rack_app("/submissions/#{submission_udid}/all_answers?#{query}", default_headers.merge(headers))
    end

    it_behaves_like "account verifier" do
      def make_call(identifier_param)
        submission_udid = create(:submission).udid
        answers = 2.times.map { create(:answer) }

        url = "/submissions/#{submission_udid}/all_answers?answers=#{answers.to_json}&callback=#{callback}#{identifier_param}"
        headers = { Referer: "http://localhost:3000" }

        rack_app(url, headers)
      end
    end

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        submission_udid = create(:submission).udid
        answers = 2.times.map { create(:answer) }

        basic_all_answers_call(account, submission_udid, answers)
      end
    end

    describe 'params validation' do
      it_behaves_like "rack parameter verifier", [:identifier, :answers], "/submissions/00000000-0000-4000-f000-000000000001/all_answers"

      it "returns a 400 if the answers is incorrect" do
        submission_udid = create(:submission).udid

        answer_arg = "/// THIS CAN'T BE DECODED ////"

        expect(basic_all_answers_call(@account, submission_udid, [], parameters: { answers: answer_arg }).code).to eq("400")
      end
    end

    describe "SubmissionsAllAnswersWorker" do
      let(:preview_mode) { nil }
      let(:submission_udid) { create(:submission).udid }

      before do
        @answers = 2.times.map { create(:answer) }
        @first_question = @answers.first.question
        @last_question = @answers.last.question

        basic_all_answers_call(@account, submission_udid, @answers, parameters: { preview_mode: preview_mode })
      end

      context "when preview mode is true" do
        let(:preview_mode) { true }

        it "does not queue SubmissionsAllAnswersWorker in preview mode" do
          expect(Sidekiq::Queue.new.size).to eq(0)
        end
      end

      context "when preview mode is false" do
        let(:preview_mode) { false }

        it "enqueues SubmissionsAllAnswersWorker" do
          expect(Sidekiq::Queue.new.size).to eq(1)
          expect(Sidekiq::Queue.new.first.item['class']).to eq('SubmissionsAllAnswersWorker')

          sidekiq_args = Sidekiq::Queue.new.first.item['args']

          expect(sidekiq_args.length).to eq 5

          expect(sidekiq_args[0]).to eq @account.identifier
          expect(sidekiq_args[1]).to eq submission_udid

          answer_args = sidekiq_args[2]
          expect(answer_args.length).to eq @answers.count
          expect(answer_args[0]).to eq(
            {
              "question_id" => @first_question.id,
              "question_type" => "single_choice_question",
              "answer" => @first_question.possible_answers.first.id
            }
          )
          expect(answer_args[1]).to eq(
            {
              "question_id" => @last_question.id,
              "question_type" => "single_choice_question",
              "answer" => @last_question.possible_answers.first.id
            }
          )

          expect(sidekiq_args[3]).to be_nil
          expect(sidekiq_args[4]).to be_nil
        end
      end
    end

    describe "response validation" do
      let(:account) { create(:account) }

      context "when successful" do
        let(:survey) { create(:survey_with_one_question, account: account) }
        let(:submission_udid) { create(:submission, survey: survey).udid }
        let(:question) { survey.questions.first }
        let(:answers) do
          [{ question_id: question.id, question_type: 'single_choice_question', answer: question.possible_answers.first.id },
           { question_id: question.id, question_type: 'single_choice_question', answer: question.possible_answers.last.id }]
        end

        before do
          survey.reload
          @response = basic_all_answers_call(account, submission_udid, [], parameters: { answers: answers.to_json })
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Submissions::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        before do
          @response = basic_all_answers_call(account, nil, [])
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Submissions::ErrorResponseSchema, @response.body
        end
      end
    end

    it_behaves_like "accounts.ips_to_block-based request blocker" do
      def make_call(preview_mode)
        survey = create(:survey_with_one_question, account: account)
        survey.reload
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.first
        answers = [{ question_id: question.id, question_type: 'single_choice_question', answer: question.possible_answers.first.id },
                   { question_id: question.id, question_type: 'single_choice_question', answer: question.possible_answers.last.id }]

        parameters = { answers: answers.to_json, preview_mode: preview_mode }
        headers = { X_REAL_IP: "192.168.0.1" }

        basic_all_answers_call(account, submission_udid, [], parameters: parameters, headers: headers)
      end

      def non_blocked_response(response)
        expect(response.code).to eq "200"

        json_response = parse_json_response(response.body)
        assert_valid_schema RackSchemas::Submissions::SuccessfulResponseSchema, json_response
      end
    end
  end
end
