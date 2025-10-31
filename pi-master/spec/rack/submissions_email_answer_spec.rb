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

  describe '/submissions/email_answer/' do
    it_behaves_like "account verifier" do
      def make_call(identifier_param)
        survey = create(:survey)
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.sort_by_position.first
        answer = question.possible_answers.sort_by_position.first

        url = "/submissions/email_answer?" \
              "question_id=#{question.id}&submission_udid=#{submission_udid}&" \
              "device_type=email&" \
              "question_#{question.id}_possible_answer_id=#{answer.id}#{identifier_param}"

        headers = {
          Referer: "http://localhost:3000",
          AMP_EMAIL_SENDER: "hello@pulseinsights.com"
        }

        rack_app(url, headers)
      end
    end

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        survey = create(:survey, account: account)
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.sort_by_position.first
        answer = question.possible_answers.sort_by_position.first

        url = "/submissions/email_answer?" \
              "question_id=#{question.id}&submission_udid=#{submission_udid}&" \
              "device_type=email&" \
              "question_#{question.id}_possible_answer_id=#{answer.id}&identifier=#{account.identifier}"

        headers = {
          Referer: "http://localhost:3000",
          AMP_EMAIL_SENDER: "hello@pulseinsights.com"
        }

        rack_app(url, headers)
      end
    end

    it_behaves_like "accounts.ips_to_block-based request blocker" do
      def make_call(preview_mode)
        survey = create(:survey_with_one_question, account: account, poll_enabled: true)
        survey.reload
        submission_udid = create(:submission, survey: survey).udid
        question = survey.questions.first
        answer = question.possible_answers.sort_by_position.first

        headers = {
          Referer: "http://localhost:3000",
          AMP_EMAIL_SENDER: "hello@pulseinsights.com",
          X_REAL_IP: "192.168.0.1"
        }

        query = {
          question_id: question.id,
          submission_udid: submission_udid,
          device_type: "email",
          "question_#{question.id}_possible_answer_id" => answer.id,
          identifier: account.identifier,
          preview_mode: preview_mode
        }.to_query

        url = "/submissions/email_answer?#{query}"

        rack_app(url, headers)
      end

      def non_blocked_response(response)
        expect(response.code).to eq "200"

        json_response = parse_json_response(response.body)
        assert_valid_schema RackSchemas::Submissions::EmailAnswerSuccessfulResponseSchema, json_response
      end
    end

    it_behaves_like "rack parameter verifier", [:identifier, :question_id], "/submissions/email_answer"

    describe "response validation" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey_with_one_question, account: account, poll_enabled: true) }
      let(:submission_udid) { create(:submission, survey: survey).udid }
      let(:question) { survey.questions.first }
      let(:answer) { question.possible_answers.sort_by_position.first }

      before do
        survey.reload

        headers = {
          Referer: "http://localhost:3000",
          AMP_EMAIL_SENDER: "hello@pulseinsights.com"
        }

        rack_app(url, headers)

        @response = rack_app(url, headers)
      end

      context "when successful" do
        let(:url) do
          "/submissions/email_answer?" \
            "question_id=#{question.id}&submission_udid=#{submission_udid}&" \
            "device_type=email&" \
            "question_#{question.id}_possible_answer_id=#{answer.id}&identifier=#{account.identifier}"
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Submissions::EmailAnswerSuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:url) do
          "/submissions/email_answer?" \
            "question_id=#{question.id}&submission_udid=#{submission_udid}&" \
            "device_type=email&" \
            "question_#{question.id}_possible_answer_id=#{answer.id}"
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Submissions::ErrorResponseSchema, @response.body
        end
      end
    end

    describe 'UpdateSubmissionViewedAtWorker' do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }
      let(:question) { survey.questions.first }

      let(:submission) { create(:submission, survey: survey) }
      let(:answer) { create(:answer, submission: submission, question: question) }

      before do
        email_answer_endpoint = '/submissions/email_answer'
        params = {
          identifier: account.identifier,
          device_type: 'email',
          question_id: question.id,
          submission_udid: submission.udid,
          "question_#{question.id}_possible_answer_id": answer.id
        }
        rack_app("#{email_answer_endpoint}?#{params.to_query}")
      end

      it 'queues a job' do
        queue = Sidekiq::Queue.new

        expect(queue.any? { |job| job['class'] == 'UpdateSubmissionViewedAtWorker' }).to be true
      end
    end

    describe "SubmissionsAnswerWorker" do
      let(:survey) { create(:survey) }
      let(:account) { survey.account }
      let(:extra_parameters) { '' }
      let(:submission_udid) { create(:submission).udid }
      let(:question) { survey.questions.sort_by_position.first }
      let(:answer) { question.possible_answers.sort_by_position.first }
      let(:question_id) { question.id }
      let(:answer_id) { answer.id }

      let(:base_url) do
        "/submissions/email_answer?" \
          "identifier=#{account.identifier}&" \
          "question_id=#{question_id}&submission_udid=#{submission_udid}&" \
          "device_type=email&" \
          "question_#{question_id}_possible_answer_id=#{answer_id}"
      end

      let(:required_headers) do
        {
          'Referer' => 'http://localhost:3000',
          "AMP_EMAIL_SENDER" => "hello@pulseinsights.com"
        }
      end

      before do
        create(:device, udid: udid)

        @response_hash = rack_app_as_json("#{base_url}#{extra_parameters}", required_headers)

        queue = Sidekiq::Queue.new
        @job_arguments = queue.first.try(:[], "args")
      end

      it "queues SubmissionsAnswerWorker" do
        queue = Sidekiq::Queue.new
        job_class = queue.first["class"]

        expect(job_class).to eq("SubmissionsAnswerWorker")
      end

      it "queues SubmissionsAnswerWorker with expected number of arguments" do
        expect(@job_arguments.length).to eq 8
      end

      context "when preview_mode has been provided" do
        let(:extra_parameters) { "&preview_mode=true" }

        it "does not queue SubmissionsAnswerWorker" do
          expect(Sidekiq::Queue.new.size).to eq 0
        end
      end

      describe "identifier" do
        subject { @job_arguments[0] }

        it { is_expected.to eq account.identifier }
      end

      describe "submission_udid" do
        subject { @job_arguments[1] }

        context 'when submission_udid has been provided' do
          it { is_expected.to eq submission_udid }
        end
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
          let(:extra_parameters) { '&text_answer=foo' }

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
          let(:extra_parameters) { "&custom_data=#{custom_data.to_json}" }

          it { is_expected.to eq custom_data.to_json }
        end

        context "when custom_data has not been provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "check_boxes" do
        subject { @job_arguments[6] }

        it { is_expected.to be_nil }
      end

      describe "client_key" do
        subject { @job_arguments[7] }

        context 'when client_key has been provided' do
          let(:extra_parameters) { "&client_key=test_key" }

          it { is_expected.to eq "test_key" }
        end

        context 'when client_key has not been provided' do
          it { is_expected.to be_nil }
        end
      end
    end
  end
end
