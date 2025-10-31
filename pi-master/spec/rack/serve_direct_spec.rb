# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')

include RackAppSpecHelper
include Rack::Database

require File.join(File.dirname(__FILE__), 'closed_by_user_spec')
require File.join(File.dirname(__FILE__), "schemas", "direct_serve_schema")

describe Rack::Serve do
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    Trigger.delete_all
    Device.delete_all
    Submission.delete_all
    DeviceData.delete_all
    Answer.delete_all
    Sidekiq::Queue.new.clear
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      create(:survey, account: create(:account))

      url = "/direct_serve?udid=#{udid}#{identifier_param}"

      rack_app(url)
    end
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      create(:survey, account: account)

      basic_direct_serve_call(account)
    end
  end

  describe "params validation" do
    it_behaves_like "rack parameter verifier", [:identifier], "/direct_serve"

    it "returns a 400 error if there's no udid and no client_key" do
      account = create(:account)

      response = basic_direct_serve_call(account, parameters: { udid: '', client_key: '' })
      expect(response.code).to eq('400')

      response = basic_direct_serve_call(account, parameters: { udid: nil, client_key: nil })
      expect(response.code).to eq('400')
    end
  end

  it_behaves_like "rack widget trigger" do
    def make_call(account, additional_query_params: {})
      basic_direct_serve_call(account, parameters: additional_query_params)
    end
  end

  it_behaves_like "rack refire limiter" do
    def make_call(account)
      parse_json_response(basic_direct_serve_call(account).body)
    end
  end

  it_behaves_like "rack frequency capped serving" do
    def make_call(account, preview_mode: false)
      parse_json_response(basic_direct_serve_call(account, parameters: { preview_mode: preview_mode }).body)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account)

      headers = { Referer: "http://localhost:3000", X_REAL_IP: "192.168.0.1" }

      query = {
        udid: udid,
        identifier: survey.account.identifier,
        preview_mode: preview_mode
      }.to_query

      url = "/direct_serve?#{query}"

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"

      json_response = parse_json_response(response.body)
      assert_valid_schema RackSchemas::DirectServe::SuccessfulResponseSchema, json_response
    end
  end

  describe '/direct_serve' do
    describe "response validation" do
      let(:account) { create(:account) }

      before do
        survey = create(:survey, account: account)

        Question.question_types.keys.map(&:to_sym).each do |question_type|
          create(question_type, survey: survey)
        end
      end

      context "when successful" do
        before do
          @response = basic_direct_serve_call(account)
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::DirectServe::SuccessfulResponseSchema, json_response

          json_response["questions_and_possible_answers"].each do |question|
            case question["question_type"]
            when "free_text_question"
              assert_valid_schema RackSchemas::Common::FreeTextQuestionSchema, question
            when "custom_content_question"
              assert_valid_schema RackSchemas::Common::CustomContentQuestionSchema, question
            when "multiple_choices_question"
              assert_valid_schema RackSchemas::Common::MultipleChoiceQuestionSchema, question
            when "slider_question"
              assert_valid_schema RackSchemas::Common::SliderQuestionSchema, question
            end
          end
        end
      end

      context "when unsuccessful" do
        before do
          @response = basic_direct_serve_call(account, parameters: { identifier: nil })
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::DirectServe::ErrorResponseSchema, @response.body
        end
      end
    end

    it "returns survey attributes and submission id" do
      account = create(:account)
      setting = account.personal_data_setting
      logo = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")
      survey = create(:survey, logo: logo, theme: create(:theme), account_id: account.id)

      json_response = parse_json_response(basic_direct_serve_call(account).body)

      assert_valid_schema RackSchemas::DirectServe::SuccessfulResponseSchema, json_response
      assert_valid_schema RackSchemas::Common::DirectSurveySchema, json_response["survey"]

      expect_survey_columns_to_select(json_response, survey)
      expect(json_response["submission"]["udid"]).to be_udid
      expect(json_response["survey"]["background_color"]).to eq(survey.background_color)
      expect(json_response["survey"]["text_color"]).to eq(survey.text_color)
      expect(json_response["survey"]["logo"].present?).to be true
      expect(survey.logo.url).to include(json_response["survey"]["logo"])
      expect(json_response["survey"]["inline_target_selector"]).to eq(survey.inline_target_selector)
      expect(json_response["survey"]["mobile_inline_target_selector"]).to eq(survey.mobile_inline_target_selector)
      expect(json_response["survey"]["sdk_inline_target_selector"]).to eq(survey.sdk_inline_target_selector)
      expect(json_response["survey"]["theme_css"]).to eq(survey.theme.css)
      expect(json_response["survey"]["answer_text_color"]).to eq(survey.answer_text_color)
      expect(json_response["survey"]["personal_data_masking_enabled"]).to eq(setting.masking_enabled)
      expect(json_response["survey"]["phone_number_masked"]).to eq(setting.phone_number_masked)
      expect(json_response["survey"]["email_masked"]).to eq(setting.email_masked)
    end

    it "returns survey localization attributes for a localized survey" do
      account = create(:account)
      survey = create(:survey, theme: create(:theme))
      survey.account = account
      survey.save
      survey.reload
      survey.localize!

      json_response = parse_json_response(basic_direct_serve_call(account).body)

      expect(json_response["survey"]["survey_locale_group_id"].to_i).to eq(survey.survey_locale_group_id)
    end

    it "returns device udid" do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save

      json_response = parse_json_response(basic_direct_serve_call(account).body)

      expect(json_response["device"]["udid"]).to eq(udid)
    end

    it "returns callback codes" do
      account = create(:account,
                       onanswer_callback_enabled: true, onanswer_callback_code: 'return onanswer_callback_code;',
                       onview_callback_enabled: true, onview_callback_code: 'return onview_callback_code;')
      create(:survey, account: account)

      json_response = parse_json_response(basic_direct_serve_call(account).body)

      expect(json_response["survey"]["onanswer_callback_code"]).to eq(account.onanswer_callback_code)
      expect(json_response["survey"]["onview_callback_code"]).to eq(account.onview_callback_code)
    end

    it "sets branding to off if it's set to off in the account level" do
      account = create(:account)
      account.pulse_insights_branding = false
      account.save
      create(:survey, account: account)

      json_response = parse_json_response(basic_direct_serve_call(account).body)
      expect(json_response["survey"]["pulse_insights_branding"]).to be(false)

      account.pulse_insights_branding = true
      account.save

      json_response = parse_json_response(basic_direct_serve_call(account).body)
      expect(json_response["survey"]["pulse_insights_branding"]).to be(true)
    end

    include_examples 'stop_showing_without_answer' do
      let(:empty_response) { ->(response) { response } }
      let(:custom_call) do
        lambda do |_survey_id, account_identifier, udid, preview_mode|
          parse_json_response(basic_direct_serve_call(Account.find_by(identifier: account_identifier),
                                                      parameters: { preview_mode: preview_mode, udid: udid }).body)
        end
      end
    end

    describe 'live preview mode' do
      context "when the survey is in draft mode" do
        before do
          account = create(:account)
          create(:survey, account: account, status: :draft)

          @json_response = parse_json_response(basic_direct_serve_call(account, parameters: { preview_mode: true }).body)
        end

        it "does not return the survey" do
          assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
        end
      end
    end

    describe 'DirectServeWorker' do
      let(:survey) { create(:survey) }
      let(:account) { survey.account }
      let(:extra_parameters) { '' }
      let(:base_url) do
        "/direct_serve?identifier=#{account.identifier}&" \
          "udid=#{udid}&client_key=#{client_key}"
      end
      let(:device_udid) { udid }

      before do
        @device = create(:device, udid: device_udid)

        @response_hash = rack_app_as_json("#{base_url}#{extra_parameters}")

        queue = Sidekiq::Queue.new
        @job_arguments = queue.first['args']
      end

      it "queues DirectServeWorker" do
        queue = Sidekiq::Queue.new
        job_class = queue.first["class"]

        expect(job_class).to eq("DirectServeWorker")
      end

      it "queues DirectServeWorker with expected number of arguments" do
        expect(@job_arguments.length).to eq 6
      end

      describe "survey_id" do
        subject { @job_arguments[0] }

        it { is_expected.to eq survey.id }
      end

      describe "submission_udid" do
        subject { @job_arguments[1] }

        it { is_expected.to eq @response_hash["submission"]["udid"] }
      end

      describe "device_id" do
        subject { @job_arguments[2] }

        context "when device associated with provided udid exists" do
          let(:device_udid) { udid }

          it { is_expected.to eq @device.id.to_s }
        end

        context "when device associated with provided udid does not exist" do
          let(:device_udid) { udid2 }

          it { is_expected.to be_nil }
        end
      end

      describe "udid" do
        subject { @job_arguments[3] }

        it { is_expected.to eq udid }
      end

      describe "custom_data" do
        subject { @job_arguments[4] }

        context "when custom_data has been provided" do
          let(:custom_data) { { a: '3', b: 'foobar' } }
          let(:extra_parameters) { "&custom_data=#{custom_data.to_json}" }

          it { is_expected.to eq custom_data.to_json }
        end

        context "when custom_data has not been provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "client_key" do
        subject { @job_arguments[5] }

        context 'when client_key is valid' do
          it { is_expected.to eq client_key }
        end

        context 'when client_key is invalid' do
          let(:client_key) { 'undefined' }

          it { is_expected.to be_nil }
        end
      end
    end

    describe 'decision based on client key' do
      before do
        @survey = create(:survey)
        @account = @survey.account
      end

      it 'renders survey if first visit' do
        json_response = parse_json_response(basic_direct_serve_call(@account, parameters: { client_key: client_key }).body)

        expect(json_response["survey"]["id"].to_i).not_to eq(0)
      end

      it 'does not render survey if different device but same client key' do
        device = create(:device, udid: udid2, client_key: client_key)
        submission = create(:submission, device_id: device.id, survey_id: @survey.id)
        create(:answer, question: @survey.reload.questions.first,
                        possible_answer: @survey.reload.questions.first.possible_answers.first,
                        submission: submission)

        json_response = parse_json_response(basic_direct_serve_call(@account, parameters: { client_key: client_key }).body)

        assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
      end
    end

    it_behaves_like "background image verifier" do
      def make_call(account)
        parse_json_response(basic_direct_serve_call(account).body)
      end
    end
  end

  # Calls the endpoint with the required parameters and headers
  def basic_direct_serve_call(account, parameters: {})
    query = {
      udid: udid,
      identifier: account.identifier
    }.merge(parameters).compact.to_query

    rack_app("/direct_serve?#{query}")
  end
end
