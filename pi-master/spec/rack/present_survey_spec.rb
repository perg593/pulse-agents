# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper
include Rack::Database

require File.join(File.dirname(__FILE__), 'closed_by_user_spec')
require File.join(File.dirname(__FILE__), "schemas", "present_survey_schema")

describe Rack::PresentSurvey do
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

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      create(:survey, account: account)

      present_survey_call(account, parameters: {identifier: account.identifier})
    end
  end

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      survey = create(:survey, account: create(:account))

      headers = { Referer: "http://localhost:3000" }

      url = "/surveys/#{survey.id}?callback=#{callback}&" \
            "udid=#{udid}&device_type=desktop" \
            "#{identifier_param}"

      rack_app(url, headers)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account)

      url = "/surveys/#{survey.id}?identifier=#{account.identifier}&callback=#{callback}&" \
            "udid=#{udid}&device_type=desktop&preview_mode=#{preview_mode}"

      headers = { Referer: "http://localhost:3000", X_REAL_IP: "192.168.0.1" }

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"

      expect(parse_json_response(response.body)["survey"]).not_to be_nil
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier, :device_type, :callback, :udid], "/surveys/42" do
    let(:optional_defaults) { { device_type: "desktop" } }
  end

  describe '/surveys/:id' do
    describe "response validation" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }
      let(:required_params) do
        {
          identifier: account.identifier,
          callback: callback,
          udid: udid,
          device_type: "desktop"
        }
      end

      before do
        headers = { Referer: "http://localhost:3000" }
        url = "/surveys/#{survey.id}?#{params.to_query}"

        @response = rack_app(url, headers)
      end

      context "when successful" do
        let(:params) { required_params }

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::PresentSurvey::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:params) do
          required_params.delete(:identifier)
          required_params
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::PresentSurvey::ErrorResponseSchema, @response.body
        end
      end
    end

    include_examples 'stop_showing_without_answer' do
      let(:empty_response) { ->(response) { response['survey'] } }

      let(:custom_call) do
        lambda do |survey_id, account_identifier, udid, preview_mode|
          rack_app_as_json("/surveys/#{survey_id}?identifier=#{account_identifier}&callback=#{callback}&" \
                           "udid=#{udid}&device_type=desktop#{preview_mode ? "&preview_mode=true" : nil}", 'Referer' => 'http://localhost:3000')
        end
      end
    end

    it "returns a response of type application/javascript" do
      account = create(:account)
      create(:survey, account: account)

      response = present_survey_call(account)
      expect(response['Content-Type']).to eq('application/javascript')
    end

    it "enqueues ServeWorker" do
      account = create(:account)
      survey = create(:survey, account: account)

      response_hash = parse_json_response(present_survey_call(account).body)

      expect(Sidekiq::Queue.new.size).to eq(1)
      expect(Sidekiq::Queue.new.first['class']).to eq('ServeWorker')

      expect(Sidekiq::Queue.new.first['args']).to eq(
        [
          {
            'identifier' => account.identifier,
            'survey_id' => survey.id,
            'submission_udid' => response_hash["submission"]["udid"],
            'device_id' => nil,
            'udid' => udid,
            'url' => "http://localhost:3000",
            'ip_address' => nil,
            'user_agent' => "Ruby",
            'client_key' => nil,
            'custom_data' => nil,
            'device_type' => "desktop",
            'visit_count' => nil,
            'pageview_count' => nil
          }
        ]
      )
    end

    it "returns survey and submission attributes" do
      account = create(:account)
      setting = account.personal_data_setting
      survey = create(:survey, theme: create(:theme), account: account)

      json_response = parse_json_response(present_survey_call(account).body)
      assert_valid_schema RackSchemas::PresentSurvey::SuccessfulResponseSchema, json_response
      assert_valid_schema RackSchemas::Common::PresentSurveySchema, json_response["survey"]

      expect_survey_columns_to_select(json_response, survey)
      expect(json_response["survey"]["theme_css"]).to eq(survey.theme.css)
      expect(json_response["survey"]["personal_data_masking_enabled"]).to eq(setting.masking_enabled)
      expect(json_response["survey"]["phone_number_masked"]).to eq(setting.phone_number_masked)
      expect(json_response["survey"]["email_masked"]).to eq(setting.email_masked)
      expect(json_response["submission"]["udid"]).not_to be_nil
    end

    it "returns callback codes" do
      account = create(:account,
                       onanswer_callback_enabled: true, onanswer_callback_code: 'return onanswer_callback_code;',
                       onview_callback_enabled: true, onview_callback_code: 'return onview_callback_code;')
      create(:survey, account: account)

      json_response = parse_json_response(present_survey_call(account).body)

      expect(json_response["survey"]["onanswer_callback_code"]).to eq(account.onanswer_callback_code)
      expect(json_response["survey"]["onview_callback_code"]).to eq(account.onview_callback_code)
    end

    it "sets branding to off if it's set to off in the account level" do
      account = create(:account)
      account.pulse_insights_branding = false
      account.save
      create(:survey, account: account)

      json_response = parse_json_response(present_survey_call(account).body)
      expect(json_response["survey"]["pulse_insights_branding"]).to be(false)

      account.pulse_insights_branding = true
      account.save

      json_response = parse_json_response(present_survey_call(account).body)
      expect(json_response["survey"]["pulse_insights_branding"]).to be(true)
    end

    describe 'enabled as false' do
      let(:account) { create(:account, enabled: false) }

      before do
        create(:survey, account: account)
        @response = present_survey_call(account)
      end

      it 'logs a message' do
        expect(@response.body).to include('This account has been deactivated by the administrator.')
      end

      it 'does not enqueue a worker' do
        expect(Sidekiq::Queue.new.size).to eq(0)
      end
    end

    it_behaves_like "background image verifier" do
      def make_call(account)
        parse_json_response(present_survey_call(account).body)
      end
    end

    describe "Non-native calls" do
      %w(desktop tablet mobile).each do |device_type|
        context "when the call is from a #{device_type}" do
          let(:response) { present_survey_call(survey.account, parameters: { device_type: device_type }) }

          context "with a #{device_type} survey" do
            let(:css_theme) { create(:theme) }
            let(:native_theme) { create(:native_theme) }

            let(:survey) { create(:survey, "#{device_type}_enabled": true, theme: css_theme, sdk_theme: native_theme) }

            it 'returns the survey' do
              expect(parse_json_response(response.body)['survey']['id']).to eq survey.id
            end

            it 'returns a css theme' do
              expect(parse_json_response(response.body)['survey']['theme_css']).to eq css_theme.css
              expect(parse_json_response(response.body)['survey']['theme_native']).to be_nil
            end

            it 'queues a ServeWorker job' do
              expect(response.code).to eq '200'

              serve_worker_job = Sidekiq::Queue.new.find { |job| job['class'] == 'ServeWorker' }
              expect(serve_worker_job).not_to be_nil

              job_arguments = serve_worker_job['args'].first
              expect(job_arguments).to include({ 'identifier' => survey.account.identifier })
              expect(job_arguments).to include({ 'survey_id' => survey.id })
              expect(job_arguments).to include({ 'device_type' => device_type })
            end
          end

          context "with a non #{device_type} survey" do
            let(:survey) { create(:survey, "#{device_type}_enabled": false) }

            it 'returns no survey' do
              expect(parse_json_response(response.body)['survey']).to eq({})
            end
          end
        end
      end
    end

    describe "Native calls" do
      let(:launch_times) { rand(100) }
      let(:install_days) { rand(100) }
      let(:view_name) { FFaker::Lorem.word }

      let(:response) do
        present_survey_call(survey.account, parameters:
          {
            device_type: 'native_mobile',
            mobile_type: mobile_type,
            launch_times: launch_times,
            install_days: install_days,
            view_name: view_name
          })
      end

      shared_examples 'native call duties' do |mobile_type|
        context "with an #{mobile_type} survey" do
          let(:css_theme) { create(:theme) }
          let(:native_theme) { create(:native_theme) }

          let(:survey) { create(:survey, "#{mobile_type}_enabled": true, theme: css_theme, sdk_theme: native_theme) }

          it 'returns the survey' do
            expect(parse_json_response(response.body)['survey']['id']).to eq survey.id
          end

          it 'returns a native theme' do
            expect(parse_json_response(response.body)['survey']['theme_native']).to eq native_theme.native_content
            expect(parse_json_response(response.body)['survey']['theme_css']).to be_nil
          end

          it 'queues a NativeServeWorker job' do
            expect(response.code).to eq '200'

            native_serve_worker_job = Sidekiq::Queue.new.find { |job| job['class'] == 'NativeServeWorker' }
            expect(native_serve_worker_job).not_to be_nil

            job_arguments = native_serve_worker_job['args'].first
            expect(job_arguments).to include({ 'identifier' => survey.account.identifier })
            expect(job_arguments).to include({ 'survey_id' => survey.id })
            expect(job_arguments).to include({ 'device_type' => 'native_mobile' })
            expect(job_arguments).to include({ 'launch_times' => launch_times })
            expect(job_arguments).to include({ 'install_days' => install_days })
            expect(job_arguments).to include({ 'view_name' => view_name })
          end
        end

        context "with no #{mobile_type} survey" do
          let(:survey) { create(:survey) }

          it 'returns no survey' do
            expect(parse_json_response(response.body)['survey']).to eq({})
          end
        end
      end

      %w(ios android).each do |mobile_type|
        context "when the call is from #{mobile_type}" do
          let(:mobile_type) { mobile_type }

          include_examples 'native call duties', mobile_type
        end
      end

      context "when the call is from native" do
        let(:mobile_type) { nil }

        %w(ios android).each do |mobile_type|
          include_examples 'native call duties', mobile_type
        end
      end
    end
  end

  # Calls the endpoint with the required parameters and headers
  def present_survey_call(account, parameters: {})
    query = {
      callback: callback,
      udid: udid,
      device_type: "desktop",
      identifier: account.identifier
    }.merge(parameters).compact.to_query

    headers = { Referer: "http://localhost:3000" }

    rack_app("/surveys/#{account.surveys.first.id}?#{query}", headers)
  end
end
