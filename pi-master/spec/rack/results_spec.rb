# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "results_schema")

describe Rack::Results do
  let(:endpoint) { "/results" }

  it_behaves_like "rack parameter verifier", [:identifier, :submission_udid], "/results"

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      submission_udid = create(:submission).udid

      query_parameters = {
        identifier: account.identifier,
        submission_udid: submission_udid
      }

      url = "#{endpoint}?#{query_parameters.to_query}"

      rack_app(url)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      submission_udid = create(:submission).udid

      query_parameters = {
        identifier: account.identifier,
        submission_udid: submission_udid,
        preview_mode: preview_mode
      }

      url = "#{endpoint}?#{query_parameters.to_query}"

      headers = { X_REAL_IP: "192.168.0.1" }

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::Results::SuccessfulResponseSchema, response.body
    end
  end

  describe "response validation" do
    let(:account) { create(:account) }
    let(:survey) { create(:survey_without_question, account: account) }

    let(:identifier) { account.identifier }
    let(:submission_udid) { create(:submission, survey: survey).udid }
    let(:callback) { nil } # Optional

    describe "JSON response" do
      def create_answer_for_question(question)
        possible_answer = question.possible_answers.first
        submission = create(:submission, survey: survey)
        create(:answer, possible_answer: possible_answer, question: @single_choice_question, survey: survey, submission: submission)
      end

      before do
        @single_choice_question = create(:single_choice_question, survey_id: survey.id, position: 0)
        2.times { create_answer_for_question(@single_choice_question) }

        @multiple_choices_question = create(:multiple_choices_question, survey: survey, position: 1)
        2.times { create_answer_for_question(@multiple_choices_question) }

        @slider_question = create(:slider_question, survey: survey, position: 2)
        2.times { create_answer_for_question(@slider_question) }

        @free_text_question = create(:free_text_question, survey: survey, position: 3)
        @custom_content_question = create(:custom_content_question, survey: survey, position: 4)

        query_parameters = {
          identifier: identifier,
          submission_udid: submission_udid,
          callback: callback,
          accept: "application/json"
        }.compact

        url = "#{endpoint}?#{query_parameters.to_query}"

        @response = rack_app(url)
      end

      it "returns 200" do
        expect(@response.code).to eq "200"
      end

      describe 'Content Type' do
        context 'without callback' do
          it "returns application/json" do
            expect(@response["Content-Type"]).to eq "application/json"
          end
        end

        context 'with callback' do
          let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_0' }

          it 'returns application/javascript' do
            expect(@response["Content-Type"]).to eq "application/javascript"
          end
        end
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::Results::SuccessfulJSONResponseSchema, JSON.parse(@response.body)
      end

      describe "values" do
        let(:json_results) { JSON.parse(@response.body)["results"] }

        RSpec::Matchers.define :contain_question do |question|
          match do |response_hash|
            response_hash["questions"].detect do |q|
              q["id"].to_i == question.id
            end
          end

          failure_message do |actual|
            "Expected #{actual} to include question with ID #{expected.id}"
          end
        end

        it "ignores free text questions" do
          expect(json_results).not_to contain_question(@free_text_question)
        end

        it "ignores custom content questions" do
          expect(json_results).not_to contain_question(@custom_content_question)
        end

        it "returns questions in position order" do
          positions = json_results["questions"].map { |question| question["position"] }

          expect(positions).to match_array positions.sort
        end

        it "returns questions" do
          expect(json_results).to contain_question(@single_choice_question)
          expect(json_results).to contain_question(@multiple_choices_question)
          expect(json_results).to contain_question(@slider_question)

          json_results["questions"].each do |result_question|
            db_question = Question.find(result_question["id"])

            expect(result_question["id"]).to eq db_question.id
            expect(result_question["position"]).to eq db_question.position
            expect(result_question["content"]).to eq db_question.content
          end
        end

        it "returns possible answers in position order" do
          json_results["questions"].each do |question|
            positions = question["possibleAnswers"].map do |possible_answer|
              possible_answer["position"]
            end

            expect(positions).to match_array positions.sort
          end
        end

        it "returns possible answers" do
          json_results["questions"].each do |question|
            db_question = Question.find(question["id"])

            expect(question["possibleAnswers"].count).to eq db_question.possible_answers.count

            question["possibleAnswers"].each do |result_possible_answer|
              db_possible_answer = PossibleAnswer.find(result_possible_answer["id"])

              expect(result_possible_answer["id"]).to eq db_possible_answer.id
              expect(result_possible_answer["position"]).to eq db_possible_answer.position
              expect(result_possible_answer["content"]).to eq db_possible_answer.content
              expect(result_possible_answer["numAnswers"]).to eq db_possible_answer.answers.count
            end
          end
        end
      end
    end

    describe "HTML response" do
      before do
        query_parameters = {
          identifier: identifier,
          submission_udid: submission_udid
        }

        url = "#{endpoint}?#{query_parameters.to_query}"

        @response = rack_app(url)
      end

      it "returns 200" do
        expect(@response.code).to eq "200"
      end

      it "returns text/html" do
        expect(@response["Content-Type"]).to eq "text/html; charset=utf-8"
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::Results::ErrorResponseSchema, @response.body
      end

      it "returns the expected values" do
        expect(@response.body.squish).to eq raw_html.squish
      end

      def raw_html
        <<-HTML
          <!DOCTYPE html>
          <html>
            <head>
              <title>Results - Crafted with Pulse Insights</title>
              <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
              <script>
                (function() {
                  var w = window, d = document;
                  w['pi']=function() {
                    w['pi'].commands = w['pi'].commands || [];
                    w['pi'].commands.push(arguments);
                  };

                  var s = d.createElement('script'); s.async = 1;
                  s.src = 'http://localhost:8888/assets/surveys.js';

                  var f = d.getElementsByTagName('script')[0];
                  f.parentNode.insertBefore(s, f);
                  pi('host', '');
                  pi('identify', '#{identifier}');
                  pi('present_results', '#{submission_udid}')
                })();
              </script>
            </head>
            <body>
            </body>
          </html>
        HTML
      end
    end
  end
end
