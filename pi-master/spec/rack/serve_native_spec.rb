# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper
include Rack::Database

require File.join(File.dirname(__FILE__), 'closed_by_user_spec')
require File.join(File.dirname(__FILE__), "schemas", "serve_native_schema")

describe Rack::Serve do
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    Trigger.delete_all
    Device.delete_all
    Submission.delete_all
    DeviceData.delete_all
    Sidekiq::Queue.new.clear
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }
  let(:default_device_type) { "native_mobile" }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  it_behaves_like "rack widget trigger" do
    def make_call(account, additional_query_params: {})
      account.surveys.first.update(ios_enabled: true)

      basic_native_serve_call(account, parameters: additional_query_params)
    end
  end

  it_behaves_like "rack geo targeting trigger" do
    def make_call(account, geotargeting_headers)
      account.surveys.first.update(ios_enabled: true)

      query = {
        identifier: account.identifier,
        udid: udid,
        device_type: default_device_type
      }.to_query

      headers = { Referer: "http://localhost:3000" }.merge(geotargeting_headers)

      rack_app_as_json("/serve?#{query}", headers)
    end
  end

  it_behaves_like "rack client key targeting" do
    def make_call(account, client_key_param)
      account.surveys.first.update(ios_enabled: true)

      parse_json_response(basic_native_serve_call(account, parameters: client_key_param).body)
    end
  end

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      create(:survey, account: create(:account), ios_enabled: true)

      url = "/serve?&callback=#{callback}&" \
            "udid=#{udid}&device_type=#{default_device_type}&" \
            "#{identifier_param}"

      headers = { Referer: "http://localhost:3000" }

      rack_app(url, headers)
    end
  end

  it_behaves_like "rack frequency capped serving" do
    def make_call(account, preview_mode: false)
      account.surveys.first.update(ios_enabled: true)

      parse_json_response(basic_native_serve_call(account, parameters: { preview_mode: preview_mode }).body)
    end
  end

  it_behaves_like "rack refire limiter" do
    def make_call(account)
      account.surveys.first.update(ios_enabled: true)

      parse_json_response(basic_native_serve_call(account).body)
    end
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      create(:survey, account: account, ios_enabled: true)

      basic_native_serve_call(account)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      create(:survey, account: account, android_enabled: true)

      headers = { Referer: "http://localhost:3000", X_REAL_IP: "192.168.0.1" }

      query = {
        identifier: account.identifier,
        callback: callback,
        udid: udid,
        device_type: default_device_type,
        preview_mode: preview_mode
      }.to_query

      url = "/serve?#{query}"

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, parse_json_response(response.body)
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier, :device_type, :udid], "/serve" do
    let(:optional_defaults) { { device_type: default_device_type } }
  end

  describe '/serve for native_mobile type' do
    describe "response validation" do
      let(:account) { create(:account) }

      before do
        create(:survey, account: account, ios_enabled: true)
      end

      context "when successful" do
        before do
          @response = basic_native_serve_call(account)
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        before do
          @response = basic_native_serve_call(account, parameters: { identifier: nil })
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::ServeNative::ErrorResponseSchema, @response.body
        end
      end
    end

    it "returns a response of type application/javascript" do
      account = create(:account)

      response = basic_native_serve_call(account)

      expect(response['Content-Type']).to eq('application/javascript')
    end

    # rubocop:disable RSpec/ExampleLength
    # We have many attributes to check
    it "returns survey attributes and submission id" do
      account = create(:account)
      setting = account.personal_data_setting

      sdk_theme = create(:theme, theme_type: :native, native_content: '{ "theme": "native" }')

      logo = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")

      survey = create(:survey, android_enabled: true, ios_enabled: true, logo: logo, theme: create(:theme), sdk_theme: sdk_theme)
      survey.account = account
      survey.save

      create(:page_after_seconds_trigger, survey: survey, render_after_x_seconds_enabled: true, render_after_x_seconds: 5)

      json_response = parse_json_response(basic_native_serve_call(account).body)

      assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
      assert_valid_schema RackSchemas::Common::NativeSurveySchema, json_response["survey"]

      expect(json_response["survey"]["invitation"]).to eq("Hello, want to take a survey?")
      expect(json_response["survey"]["width"].to_i).to eq(300)
      expect(json_response["survey"]["render_after_x_seconds"].to_i).not_to eq('5')
      expect(json_response["survey"]["render_after_x_seconds_enabled"].to_i).not_to eq('t')
      expect(json_response["survey"]["thank_you"]).to eq("*Thank you* for your feedback!")
      expect(json_response["submission"]["udid"]).not_to be_nil
      expect(json_response["survey"]["id"].to_i).to eq(survey.id)
      expect(json_response["survey"]["survey_type"].to_i).to eq(Survey.survey_types[survey.survey_type])
      expect(json_response["survey"]["top_position"]).to eq(survey.top_position)
      expect(json_response["survey"]["bottom_position"]).to eq(survey.bottom_position)
      expect(json_response["survey"]["left_position"]).to eq(survey.left_position)
      expect(json_response["survey"]["right_position"]).to eq(survey.right_position)
      expect(json_response["survey"]["background_color"]).to eq(survey.background_color)
      expect(json_response["survey"]["text_color"]).to eq(survey.text_color)
      expect(json_response["survey"]["logo"].present?).to be true
      expect(survey.logo.url).to include(json_response["survey"]["logo"])
      expect(json_response["survey"]["inline_target_selector"]).to eq(survey.inline_target_selector)
      expect(json_response["survey"]["mobile_inline_target_selector"]).to eq(survey.mobile_inline_target_selector)
      expect(json_response["survey"]["custom_css"]).to eq(survey.custom_css)
      expect(json_response["survey"]["theme_native"]).to eq(survey.sdk_theme.native_content)
      expect(json_response["survey"]["answer_text_color"]).to eq(survey.answer_text_color)
      expect(json_response["survey"]["render_after_x_seconds"].to_i).to eq(survey.page_after_seconds_trigger.render_after_x_seconds)
      expect(json_response["survey"]["render_after_x_seconds_enabled"]).to eq(survey.page_after_seconds_trigger.render_after_x_seconds_enabled ? "t" : "f")
      expect(json_response["survey"]["pusher_enabled"]).to eq(survey.pusher_enabled ? "t" : "f")
      expect(json_response["survey"]["sdk_inline_target_selector"]).to eq(survey.sdk_inline_target_selector)
      expect(json_response["survey"]["display_all_questions"]).to eq(survey.display_all_questions ? "t" : "f")
      expect(json_response["survey"]["fullscreen_margin"]).to eq(survey.fullscreen_margin)
      expect(json_response["survey"]["invitation_button"]).to eq(survey.invitation_button)
      expect(json_response["survey"]["invitation_button_disabled"]).to eq(survey.invitation_button_disabled ? "t" : "f")
      expect(json_response["survey"]["single_page"]).to eq(survey.single_page ? "t" : "f")
      expect(json_response["survey"]["randomize_question_order"]).to eq(survey.randomize_question_order ? "t" : "f")
      expect(json_response["survey"]["pulse_insights_branding"]).to eq(survey.account.pulse_insights_branding)
      expect(json_response["survey"]["custom_data_snippet"]).to eq(survey.account.custom_data_snippet)
      expect(json_response["survey"]["onclose_callback_code"]).to eq(survey.account.onclose_callback_code)
      expect(json_response["survey"]["oncomplete_callback_code"]).to eq(survey.account.oncomplete_callback_code)
      expect(json_response["survey"]["onanswer_callback_code"]).to eq(survey.account.onanswer_callback_code)
      expect(json_response["survey"]["inline_target_position"].to_i).to eq(Survey.inline_target_positions[survey.inline_target_position])
      expect(json_response["survey"]["all_at_once_submit_label"]).to eq(survey.all_at_once_submit_label)
      expect(json_response["survey"]["all_at_once_error_text"]).to eq(survey.all_at_once_error_text)
      expect(json_response["survey"]["personal_data_masking_enabled"]).to eq(setting.masking_enabled)
      expect(json_response["survey"]["phone_number_masked"]).to eq(setting.phone_number_masked)
      expect(json_response["survey"]["email_masked"]).to eq(setting.email_masked)
      expect(json_response["survey"]["sdk_widget_height"]).to eq(survey.sdk_widget_height)
    end

    describe "sdk_widget_height constraints" do
      let(:account) { create(:account) }
      let(:sdk_widget_height) { 42 }

      before do
        @survey = create(:survey, ios_enabled: true, account: account, sdk_widget_height: sdk_widget_height, survey_type: survey_type)
        @json_response = parse_json_response(basic_native_serve_call(account).body)
      end

      [:docked_widget, :fullscreen].each do |unsupported_survey_type|
        context "when the survey type is not supported -- #{unsupported_survey_type}" do
          let(:survey_type) { unsupported_survey_type }

          it "returns 0" do
            expect(@json_response["survey"]["sdk_widget_height"]).to eq(0)
          end
        end
      end

      [:inline, :top_bar, :bottom_bar].each do |supported_survey_type|
        context "when the survey type is supported -- #{supported_survey_type}" do
          let(:survey_type) { supported_survey_type }

          it "returns surveys.sdk_widget_height" do
            expect(@json_response["survey"]["sdk_widget_height"]).to eq(sdk_widget_height)
          end
        end
      end
    end

    describe 'pageview trigger' do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, ios_enabled: true) }

      def assert_view_names(view_names, trigger_survey:)
        view_names.each do |view_name|
          response = basic_native_serve_call(account, parameters: { view_name: view_name })
          json_response = parse_json_response(response.body)

          if trigger_survey
            assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
          else
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
          end
        end
      end

      def assert_view_names_trigger_survey(view_names)
        assert_view_names(view_names, trigger_survey: true)
      end

      def assert_view_names_do_not_trigger_survey(view_names)
        assert_view_names(view_names, trigger_survey: false)
      end

      context "when no triggers defined,and there are suppressers defined but no one triggered" do
        before do
          create(:mobile_regexp_trigger, mobile_regexp: '^localhost:3000/$', survey: survey, excluded: true)
        end

        it "respects trigger rules" do
          assert_view_names_do_not_trigger_survey(["localhost:3000/"])
        end
      end

      context "when there is one pageview trigger" do
        before do
          create(:mobile_pageview_trigger, mobile_pageview: '/abc', survey: survey)
        end

        it "respects trigger rules" do
          assert_view_names_trigger_survey(["http://localhost:3000/abc", "http://localhost:3000/abcdef", "http://localhost:3000/123/abc"])

          assert_view_names_do_not_trigger_survey(["http://localhost:3000", "http://localhost:3000/bla"])
        end
      end

      context "when there is one regexp trigger" do
        before do
          create(:mobile_regexp_trigger, mobile_regexp: '/abc[0-9]/', survey: survey)
        end

        it "respects trigger rules" do
          assert_view_names_trigger_survey(["http://localhost:3000/abc3/"])

          assert_view_names_do_not_trigger_survey(["http://localhost:3000", "http://localhost:3000/abc00/"])
        end
      end

      context "when there is more than one regexp trigger" do
        before do
          create(:mobile_regexp_trigger, mobile_regexp: '^domain.com/thank_you/users/[0-9]*$', survey: survey)
          create(:mobile_regexp_trigger, mobile_regexp: '/payments/[0-9]*/done$', survey: survey)
        end

        it "respects trigger rules" do
          assert_view_names_trigger_survey(["domain.com/thank_you/users/123", "domain.com/payments/123/done"])

          assert_view_names_do_not_trigger_survey(["domain.com/thank_you/users/123/should-not-be-here", "domain.com/should-not-be-here/thank_you/users/123",
                                                   "domain.com/payments/should-not-work/done"])
        end
      end

      it "respects suppressers" do
        create(:mobile_regexp_trigger, mobile_regexp: '^domain\.(org|net|com)', survey: survey)
        create(:mobile_regexp_trigger, mobile_regexp: 'checkout/[0-9]*', survey: survey, excluded: true)
        create(:mobile_regexp_trigger, mobile_regexp: '/contact', survey: survey, excluded: true)

        expect(survey.reload.suppressers.count).to eq(2)

        assert_view_names_do_not_trigger_survey(["domain.com/checkout/123", "domain.com/contact"])

        assert_view_names_trigger_survey(["domain.com/anything-else", "domain.com"])
      end
    end

    describe 'launch days trigger' do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, android_enabled: true, ios_enabled: true, account: account) }

      describe 'days = 0' do
        before do
          create(:mobile_launch_trigger, survey: survey, mobile_launch_times: 0)
        end

        [nil, 0, 5].each do |launch_times|
          context "when mobile_launch_times = #{launch_times}" do
            it "returns survey" do
              response = basic_native_serve_call(account, parameters: { launch_times: launch_times })
              json_response = parse_json_response(response.body)

              assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
            end
          end
        end
      end

      describe 'days = 10' do
        before do
          create(:mobile_launch_trigger, survey: survey, mobile_launch_times: 10)

          response = basic_native_serve_call(account, parameters: { launch_times: launch_times })
          @json_response = parse_json_response(response.body)
        end

        context "when mobile_launch_times = nil" do
          let(:launch_times) { nil }

          it "does not return survey" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end
        end

        context "when mobile_launch_times < 10" do
          let(:launch_times) { 9 }

          it "does not return survey" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end
        end

        context "when mobile_launch_times = 10" do
          let(:launch_times) { 10 }

          it "returns the survey" do
            assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, @json_response
          end
        end

        context "when mobile_launch_times > 10" do
          let(:launch_times) { 15 }

          it "returns the survey" do
            assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, @json_response
          end
        end
      end
    end

    describe 'days installed trigger' do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, android_enabled: true, ios_enabled: true, account: account) }

      describe 'days = 0' do
        before do
          create(:mobile_install_trigger, survey: survey, mobile_days_installed: 0)
        end

        [nil, 0, 5].each do |install_days|
          context "when mobile_days_installed = #{install_days}" do
            it "returns survey" do
              response = basic_native_serve_call(account, parameters: { install_days: install_days })
              json_response = parse_json_response(response.body)

              assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
            end
          end
        end
      end

      describe 'days = 10' do
        before do
          create(:mobile_install_trigger, survey: survey, mobile_days_installed: 10)

          response = basic_native_serve_call(account, parameters: { install_days: install_days })
          @json_response = parse_json_response(response.body)
        end

        context "when install_days = nil" do
          let(:install_days) { nil }

          it "does not return survey" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end
        end

        context "when install_days < 10" do
          let(:install_days) { 9 }

          it "does not return survey" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end
        end

        context "when install_days = 10" do
          let(:install_days) { 10 }

          it "returns survey" do
            assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, @json_response
          end
        end

        context "when install_days > 10" do
          let(:install_days) { 11 }

          it "returns the survey" do
            assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, @json_response
          end
        end
      end
    end

    describe 'stop_showing_without_answer' do
      include_examples 'stop_showing_without_answer' do
        let(:survey) { create(:survey_with_account, android_enabled: true, ios_enabled: true) }
        let(:empty_response) { ->(response) { response } }

        let(:custom_call) do
          lambda do |_survey_id, account_identifier, udid, preview_mode|
            rack_app_as_json("/serve?identifier=#{account_identifier}&callback=#{callback}&" \
                             "udid=#{udid}&device_type=#{default_device_type}#{preview_mode ? "&preview_mode=true" : nil}", 'Referer' => 'http://localhost:3000')
          end
        end
      end
    end

    it_behaves_like "background image verifier" do
      def make_call(account)
        account.surveys.first.update(android_enabled: true, ios_enabled: true)

        parse_json_response(basic_native_serve_call(account).body)
      end
    end

    describe 'theme_native' do
      let(:account) { create(:account) }
      let!(:survey) { create(:survey, account: account, ios_enabled: true) }

      context 'when survey has theme for sdk' do
        before do
          @theme_content = { "theme" => "native" }
          theme = create(:theme, theme_type: :native, native_content: @theme_content)

          survey.update(sdk_theme: theme)
        end

        it "serves the sdk theme" do
          response = parse_json_response(basic_native_serve_call(account).body)

          expect(response['survey']['theme_native']).to eq(@theme_content)
        end
      end

      context 'when survey does not have theme for sdk' do
        it 'returns null as the sdk theme' do
          response = parse_json_response(basic_native_serve_call(account).body)

          expect(response['survey'].keys).to include('theme_native')
          expect(response['survey']['theme_native']).to be_nil
        end
      end
    end

    describe 'client key trigger' do
      let!(:account) { create(:account) }
      let(:survey) { create(:survey, account: account, android_enabled: true, ios_enabled: true) }
      let(:device) { create(:device, udid: udid) }

      let(:serve_url) { "/serve?identifier=#{account.identifier}&udid=#{udid}&device_type=native_mobile&mobile_type=android" }

      context 'when it is enabled' do
        before do
          create(:client_key_trigger, survey: survey, client_key_presence: true)
        end

        it 'returns a survey if a device with the specific client_key exists' do
          device.update(client_key: client_key)

          response = rack_app_as_json(serve_url + "&client_key=#{client_key}")

          expect(response["survey"]["id"]).not_to be_nil
        end

        it 'does not return a survey if no client key is passed' do
          response = rack_app_as_json(serve_url)

          expect(response).to eq({})
        end

        it 'does not return a survey if there is no matching device' do
          device.update(client_key: client_key * 2)

          response = rack_app_as_json(serve_url + "&client_key=#{client_key}")

          expect(response).to eq({})
        end
      end

      context 'when it is disabled' do
        before do
          create(:client_key_trigger, survey: survey, client_key_presence: false)
        end

        it 'returns a survey' do
          response = rack_app_as_json(serve_url)

          expect(response["survey"]["id"]).not_to be_nil
        end
      end
    end
  end

  describe "mobile type" do
    let(:account) { create(:account) }

    let(:ios_enabled) { false }
    let(:android_enabled) { false }

    let(:mobile_type) { nil }

    before do
      create(:survey, ios_enabled: ios_enabled, android_enabled: android_enabled, account: account)

      query = {
        identifier: account.identifier,
        udid: udid,
        device_type: default_device_type
      }

      query[:mobile_type] = mobile_type if mobile_type.present?
      query = query.to_query

      @response = rack_app("/serve?#{query}")
    end

    def assert_returns_survey
      assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, parse_json_response(@response.body)
    end

    def assert_does_not_return_survey
      assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, parse_json_response(@response.body)
    end

    context "when mobile type is invalid" do
      let(:mobile_type) { "foo" }

      it "returns an error" do
        assert_valid_schema RackSchemas::ServeNative::ErrorResponseSchema, @response

        expect(@response.code).to eq("400")
        expect(@response.body).to eq("Error: Parameter 'mobile_type' '#{mobile_type}' is invalid")
      end
    end

    context "when survey only has ios enabled" do
      let(:ios_enabled) { true }

      context 'when mobile type is ios' do
        let(:mobile_type) { "ios" }

        it 'returns survey' do
          assert_returns_survey
        end
      end

      context 'when mobile type is android' do
        let(:mobile_type) { "android" }

        it 'does not return survey' do
          assert_does_not_return_survey
        end
      end

      context 'when mobile type is not provided' do
        let(:mobile_type) { nil }

        it 'returns survey' do
          assert_returns_survey
        end
      end
    end

    context 'when survey only has android enabled' do
      let(:android_enabled) { true }

      context 'when mobile type is android' do
        let(:mobile_type) { "android" }

        it 'returns survey' do
          assert_returns_survey
        end
      end

      context 'when mobile type is ios' do
        let(:mobile_type) { "ios" }

        it 'does not return survey' do
          assert_does_not_return_survey
        end
      end

      context 'when mobile type is not provided' do
        let(:mobile_type) { nil }

        it 'returns survey' do
          assert_returns_survey
        end
      end
    end

    context 'when survey has both ios and android enabled' do
      let(:android_enabled) { true }
      let(:ios_enabled) { true }

      context 'when mobile type is ios' do
        let(:mobile_type) { "ios" }

        it 'returns survey' do
          assert_returns_survey
        end
      end

      context 'when mobile type is android' do
        let(:mobile_type) { "android" }

        it 'returns survey' do
          assert_returns_survey
        end
      end

      context 'when mobile type is not provided' do
        let(:mobile_type) { nil }

        it 'returns survey' do
          assert_returns_survey
        end
      end
    end

    context 'when survey has ios and android disabled' do
      before do
        create(:survey, account_id: account.id)
      end

      context 'when mobile type is ios' do
        let(:mobile_type) { "ios" }

        it 'does not return survey' do
          assert_does_not_return_survey
        end
      end

      context 'when mobile type is android' do
        let(:mobile_type) { "android" }

        it 'does not return survey' do
          assert_does_not_return_survey
        end
      end

      context 'when mobile type is not provided' do
        let(:mobile_type) { nil }

        it 'does not return survey' do
          assert_does_not_return_survey
        end
      end
    end
  end

  describe 'live preview mode' do
    let(:account) { create(:account) }

    before do
      create(:survey, ios_enabled: true, account: account, status: 0)
    end

    it "returns surveys in DRAFT" do
      response = basic_native_serve_call(account, parameters: { preview_mode: "true" })

      json_response = parse_json_response(response.body)
      assert_valid_schema RackSchemas::ServeNative::SuccessfulResponseSchema, json_response
    end
  end

  describe 'NativeServeWorker' do
    let(:account) { create(:survey, android_enabled: true).account }
    let(:mobile_type) { "android" }
    let(:device_udid) { udid }
    let(:extra_parameters) { {} }

    def expected_worker_keys
      %w(
        client_key
        custom_data
        device_id
        device_type
        install_days
        ip_address
        launch_times
        mobile_type
        submission_udid
        survey_id
        udid
        user_agent
        view_name
      )
    end

    before do
      @device = create(:device, udid: device_udid)

      basic_native_serve_call(account, parameters: { client_key: client_key, mobile_type: mobile_type }.merge(extra_parameters))

      queue = Sidekiq::Queue.new
      @job_arguments = queue.first['args'][0]
    end

    it "queues NativeServeWorker" do
      queue = Sidekiq::Queue.new
      job_class = queue.first["class"]

      expect(job_class).to eq("NativeServeWorker")
    end

    it "queues NativeServeWorker with the expected arguments" do
      expect(@job_arguments.keys).to match_array(expected_worker_keys)
    end

    describe "client_key" do
      subject { @job_arguments["client_key"] }

      context 'when client_key is valid' do
        it { is_expected.to eq client_key }
      end

      context 'when client_key is invalid' do
        let(:client_key) { 'undefined' }

        it { is_expected.to be_nil }
      end
    end

    describe "custom_data" do
      subject { @job_arguments["custom_data"] }

      context "when custom_data has been provided" do
        let(:custom_data) { { a: '3', b: 'foobar' } }
        let(:extra_parameters) { { custom_data: custom_data.to_json } }

        it { is_expected.to eq custom_data.to_json }
      end

      context "when custom_data has not been provided" do
        it { is_expected.to be_nil }
      end
    end

    describe "device_id" do
      subject { @job_arguments["device_id"] }

      context "when device associated with provided udid exists" do
        let(:device_udid) { udid }

        it { is_expected.to eq @device.id.to_s }
      end

      context "when device associated with provided udid does not exist" do
        let(:device_udid) { udid2 }

        it { is_expected.to be_nil }
      end
    end

    describe "device_type" do
      subject { @job_arguments["device_type"] }

      it { is_expected.to eq default_device_type }
    end

    describe "ip_address" do
      subject { @job_arguments["ip_address"] }

      it { is_expected.to be_nil } # Test environment won't have an IP address
    end

    describe "install_days" do
      subject { @job_arguments["install_days"] }

      context "when install_days has been provided" do
        let(:extra_parameters) { { install_days: 42 } }

        it { is_expected.to eq 42 }
      end

      context "when install_days has not been provided" do
        it { is_expected.to eq 0 }
      end
    end

    describe "launch_times" do
      subject { @job_arguments["launch_times"] }

      context "when launch_times has been provided" do
        let(:extra_parameters) { { launch_times: 42 } }

        it { is_expected.to eq 42 }
      end

      context "when launch_times has not been provided" do
        it { is_expected.to eq 0 }
      end
    end

    describe "mobile_type" do
      subject { @job_arguments["mobile_type"] }

      it { is_expected.to eq mobile_type }
    end

    describe "submission_udid" do
      subject { @job_arguments["submission_udid"] }

      # Randomly generated on the backend
      # We could mock the backend's udid generator, but that's gross
      it { is_expected.not_to be_nil }
    end

    describe "udid" do
      subject { @job_arguments["udid"] }

      it { is_expected.to eq udid }
    end

    describe "survey_id" do
      subject { @job_arguments["survey_id"] }

      it { is_expected.to eq account.surveys.first.id }
    end

    describe "user_agent" do
      subject { @job_arguments["user_agent"] }

      let(:user_agent) { "Ruby" }

      it { is_expected.to eq user_agent }
    end

    describe "view_name" do
      subject { @job_arguments["view_name"] }

      context "when view_name is provided" do
        let(:extra_parameters) { { view_name: "testView" } }

        it { is_expected.to eq "testView" }
      end

      context "when view_name is not provided" do
        it { is_expected.to be_nil }
      end
    end
  end

  # Calls the endpoint with the required parameters
  def basic_native_serve_call(account, parameters: {})
    query = {
      device_type: default_device_type,
      identifier: account.identifier,
      udid: udid
    }.merge(parameters).to_query

    rack_app("/serve?#{query}")
  end
end
