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

  describe '/submissions/:id/answer/' do
    # Calls the endpoint with the required parameters and headers
    def basic_answer_call(account_identifier, submission_udid, question_id, parameters: {}, headers: {})
      query = {
        identifier: account_identifier,
        question_id: question_id,
        callback: callback
      }.merge(parameters).to_query

      default_headers = { Referer: "http://localhost:3000" }

      rack_app("/submissions/#{submission_udid}/answer?#{query}", default_headers.merge(headers))
    end

    it_behaves_like "account verifier" do
      def make_call(identifier_param)
        survey = create(:survey)
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.sort_by_position.first
        answer = question.possible_answers.sort_by_position.first

        url = "/submissions/#{submission_udid}/answer?" \
              "callback=#{callback}&question_id=#{question.id}&answer_id=#{answer.id}#{identifier_param}"

        headers = { Referer: "http://localhost:3000" }

        rack_app(url, headers)
      end
    end

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        survey = create(:survey, account: account)
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.sort_by_position.first
        answer = question.possible_answers.sort_by_position.first

        basic_answer_call(account.identifier, submission_udid, question.id, parameters: { answer_id: answer.id })
      end
    end

    describe "response validation" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey_with_one_question, account: account, poll_enabled: true) }
      let(:submission_udid) { create(:submission, survey: survey).udid }
      let(:question) { survey.questions.first }
      let(:answer) { question.possible_answers.sort_by_position.first }

      before do
        survey.reload

        headers = { Referer: "http://localhost:3000" }

        rack_app(url, headers)

        @response = rack_app(url, headers)
      end

      context "when successful" do
        let(:url) do
          "/submissions/#{submission_udid}/answer?" \
            "identifier=#{account.identifier}&callback=#{callback}&" \
            "question_id=#{question.id}&answer_id=#{answer.id}"
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Submissions::AnswerSuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:url) do
          "/submissions/#{submission_udid}/answer?" \
            "&callback=#{callback}&" \
            "question_id=#{question.id}&answer_id=#{answer.id}"
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Submissions::ErrorResponseSchema, @response.body
        end
      end
    end

    it_behaves_like "rack parameter verifier", [:identifier, :question_id], "/submissions/00000000-0000-4000-f000-000000000001/answer"

    describe 'params validation' do
      it "returns a 400 error if there's no answer id" do
        account = create(:account)
        survey = create(:survey, account: account)

        question_id = survey.questions.first.id

        submission_udid = create(:submission, survey: survey).udid
        expect(basic_answer_call(account.identifier, submission_udid, question_id).code).to eq("400")
      end

      it_behaves_like "accounts.ips_to_block-based request blocker" do
        def make_call(preview_mode)
          survey = create(:survey, account: account)
          survey.reload
          submission_udid = create(:submission, survey: survey).udid
          question = survey.questions.first
          answer = question.possible_answers.sort_by_position.first

          parameters = { answer_id: answer.id, preview_mode: preview_mode }
          headers = { X_REAL_IP: "192.168.0.1" }

          basic_answer_call(account.identifier, submission_udid, question.id, parameters: parameters, headers: headers)
        end

        def non_blocked_response(response)
          expect(response.code).to eq "200"

          json_response = parse_json_response(response.body)
          assert_valid_schema RackSchemas::Submissions::AnswerSuccessfulResponseSchema, json_response
        end
      end
    end

    describe "SubmissionsAnswerWorker" do
      let(:survey) { create(:survey) }
      let(:account) { survey.account }
      let(:extra_parameters) { {} }
      let(:submission_udid) { create(:submission).udid }
      let(:question) { survey.questions.sort_by_position.first }
      let(:answer) { question.possible_answers.sort_by_position.first }
      let(:question_id) { question.id }
      let(:answer_id) { answer.id }

      before do
        create(:device, udid: udid)

        parameters = { answer_id: answer_id }.merge(extra_parameters)
        headers = { X_REAL_IP: "192.168.0.1" }

        @response_hash = parse_json_response(
          basic_answer_call(account.identifier, submission_udid, question_id, parameters: parameters, headers: headers).body
        )

        queue = Sidekiq::Queue.new
        @job_arguments = queue&.first.try(:[], "args")
      end

      it "queues SubmissionsAnswerWorker" do
        queue = Sidekiq::Queue.new
        job_class = queue.first["class"]

        expect(job_class).to eq("SubmissionsAnswerWorker")
      end

      it "queues SubmissionsAnswerWorker with expected number of arguments" do
        expect(@job_arguments.length).to eq 8
      end

      describe "identifier" do
        subject { @job_arguments[0] }

        it { is_expected.to eq account.identifier }
      end

      describe "submission_udid" do
        subject { @job_arguments[1] }

        it { is_expected.to eq submission_udid }
      end

      describe "question_id" do
        subject { @job_arguments[2] }

        context 'when question_id has been provided' do
          it { is_expected.to eq question_id.to_s }
        end
      end

      describe "answer_id" do
        subject { @job_arguments[3] }

        context 'when answer_id has been provided' do
          it { is_expected.to eq answer_id.to_s }
        end
      end

      describe "text_answer" do
        subject { @job_arguments[4] }

        context 'when text_answer has been provided' do
          let(:answer_id) { '' }
          let(:extra_parameters) { { text_answer: "foo" } }

          it "answer_id should be blank" do
            expect(@job_arguments[3]).to eq ""
          end

          it { is_expected.to eq "foo" }
        end

        context 'when text_answer has not been provided' do
          it { is_expected.to be_nil }
        end
      end

      describe "custom_data" do
        subject { @job_arguments[5] }

        context "when custom_data has been provided" do
          let(:custom_data) { { a: '3', b: 'foobar' } }
          let(:extra_parameters) { { custom_data: custom_data.to_json} }

          it { is_expected.to eq custom_data.to_json }
        end

        context "when custom_data has not been provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "check_boxes" do
        subject { @job_arguments[6] }

        context 'when check_boxes has been provided' do
          let(:extra_parameters) { { check_boxes: [question.possible_answers.first.id, question.possible_answers.last.id].join(",") } }

          it { is_expected.to eq [question.possible_answers.sort_by_position.first.id.to_s, question.possible_answers.sort_by_position.last.id.to_s].join(",") }
        end

        context 'when check_boxes has not been provided' do
          it { is_expected.to be_nil }
        end
      end

      describe "client_key" do
        subject { @job_arguments[7] }

        context 'when client_key has been provided' do
          let(:extra_parameters) { { client_key: "test_key" } }

          it { is_expected.to eq "test_key" }
        end

        context 'when client_key has not been provided' do
          it { is_expected.to be_nil }
        end
      end

      context "when preview mode is true" do
        let(:extra_parameters) { { preview_mode: true } }

        it "does not enqueue SubmissionsAnswerWorker" do
          expect(Sidekiq::Queue.new.size).to eq(0)
        end
      end
    end

    describe "polls" do
      let(:account) { create(:account) }
      let(:submission_udid) { create(:submission, survey: survey).udid }

      context "when poll_enabled is false" do
        let(:survey) { create(:survey_with_one_question, account: account) }
        let(:question) { survey.reload.questions.first }

        it "returns no poll results" do
          answer_id = question.possible_answers.first.id

          json_response = parse_json_response(basic_answer_call(account.identifier, submission_udid, question.id, parameters: { answer_id: answer_id }).body)

          assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
        end
      end

      context "when poll_enabled is true" do
        let(:survey) { create(:survey_without_question, account: account, poll_enabled: true) }

        # TODO: Fix this behaviour. The code that performs the question check is buggy.
        # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/blob/2518-rack-app-specs/rack/database/database_getters.rb#L29
        #
        # context "when the survey has more than one question" do
        #   before do
        #     2.times { create(:question, survey: survey) }
        #     survey.reload
        #   end
        #
        #   it "returns no poll results" do
        #     answer_id = survey.questions.first.possible_answers.first.id
        #
        #     json_response = parse_json_response(
        #       basic_answer_call(account.identifier, submission_udid, survey.questions.first.id, parameters: { answer_id: answer_id }).body
        #     )
        #
        #     assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
        #   end
        # end

        def assert_poll_response_valid(json_response, possible_answers)
          expect(json_response.count).to eq(possible_answers.count)

          json_response.each_with_index do |response_object, i|
            expect(response_object).to eq(
              {
                "id" => possible_answers[i].id.to_s,
                "content" => possible_answers[i].content,
                "count" => possible_answers[i].answers.count
              }
            )
          end
        end

        context "when single choice question" do
          let(:question) { create(:single_choice_question, survey: survey) }

          it "returns poll results" do
            answer_id = question.possible_answers.first.id

            json_response = parse_json_response(
              basic_answer_call(account.identifier, submission_udid, question.id, parameters: { answer_id: answer_id }).body
            )

            assert_poll_response_valid(json_response, question.possible_answers)
          end
        end

        context "when multiple choice question" do
          let(:question) { create(:multiple_choices_question, survey: survey) }
          let(:possible_answers) { question.possible_answers.order(:position) }

          context "when a single possible answer is selected" do
            it "returns poll results" do
              answer_id = possible_answers.first.id

              json_response = parse_json_response(
                basic_answer_call(account.identifier, submission_udid, question.id, parameters: { answer_id: answer_id }).body
              )

              assert_poll_response_valid(json_response, question.possible_answers)
            end
          end

          context "when multiple answers" do
            before do
              @answer_ids = possible_answers.map(&:id).join(",")

              @json_response = parse_json_response(
                basic_answer_call(account.identifier, submission_udid, question.id, parameters: { check_boxes: @answer_ids }).body
              )
            end

            it "returns poll results" do
              assert_poll_response_valid(@json_response, question.possible_answers)
            end

            it "sends multiple IDs to Sidekiq" do
              worker_arguments = Sidekiq::Queue.new.first.item["args"]

              expect(worker_arguments[6]).to eq @answer_ids
            end
          end
        end

        context "when custom content question" do
          let(:question) { create(:custom_content_question, survey: survey) }

          before do
            @json_response = parse_json_response(
              basic_answer_call(account.identifier, submission_udid, question.id, parameters: { text_answer: "toto" }).body
            )
          end

          it "returns no poll results" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end

          it "sends text answers to Sidekiq" do
            worker_arguments = Sidekiq::Queue.new.first.item["args"]

            expect(worker_arguments[4]).to eq "toto"
          end
        end

        context "when free text question" do
          let(:question) { create(:free_text_question, survey: survey) }

          it "returns no poll results" do
            json_response = parse_json_response(
              basic_answer_call(account.identifier, submission_udid, question.id, parameters: { text_answer: "toto" }).body
            )

            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
          end
        end
      end
    end
  end
end
