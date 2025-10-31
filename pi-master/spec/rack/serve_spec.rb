# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper
include Rack::Database

require File.join(File.dirname(__FILE__), 'closed_by_user_spec')
require File.join(File.dirname(__FILE__), "schemas", "serve_schema")

describe Rack::Serve do
  before do
    Device.delete_all
    Submission.delete_all
    DeviceData.delete_all
    Sidekiq::Queue.new.clear
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  describe '/serve' do
    include_examples 'stop_showing_without_answer' do
      let(:empty_response) { ->(response) { response } }

      let(:custom_call) do
        lambda do |_survey_id, account_identifier, udid, preview_mode|
          rack_app_as_json("/serve?identifier=#{account_identifier}&callback=#{callback}&" \
                           "udid=#{udid}&device_type=desktop#{preview_mode ? "&preview_mode=true" : nil}", 'Referer' => 'http://localhost:3000')
        end
      end
    end

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
          @response = basic_serve_call(account)
        end

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        before do
          # Missing all required parameters and headers
          @response = rack_app("/serve")
        end

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::Serve::ErrorResponseSchema, @response.body
        end
      end
    end

    it_behaves_like "rack parameter verifier", [:identifier, :device_type, :callback, :udid], "/serve" do
      let(:optional_defaults) { { device_type: "desktop" } }
    end

    it "returns a response of type application/javascript" do
      account = create(:account)
      response = basic_serve_call(account)

      expect(response["Content-Type"]).to eq('application/javascript')
    end

    describe "trigger attributes" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }

      context "when a PageScrollTrigger is defined" do
        before do
          @trigger = create(:page_scroll_trigger, render_after_x_percent_scroll_enabled: true, render_after_x_percent_scroll: 3, survey: survey)
        end

        it "returns PageScrollTrigger attributes" do
          json_response = parse_json_response(basic_serve_call(account).body)

          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

          assert_valid_schema RackSchemas::Common::SurveySchema, json_response["survey"]

          expect(json_response["survey"]["render_after_x_percent_scroll_enabled"]).to eq("t")
          expect(json_response["survey"]["render_after_x_percent_scroll"]).to eq(@trigger.render_after_x_percent_scroll)
        end
      end

      context "when a PageIntentExitTrigger is defined" do
        before do
          @trigger = create(:page_intent_exit_trigger, render_after_intent_exit_enabled: true, survey: survey)
        end

        it "returns PageIntentExitTrigger attributes" do
          json_response = parse_json_response(basic_serve_call(account).body)

          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

          assert_valid_schema RackSchemas::Common::SurveySchema, json_response["survey"]

          expect(json_response["survey"]["render_after_intent_exit_enabled"]).to eq("t")
        end
      end

      context "when a PageElementClicked is defined" do
        before do
          @trigger = create(:page_element_clicked_trigger, render_after_element_clicked_enabled: true, render_after_element_clicked: "#foo", survey: survey)
        end

        it "returns PageIntentExitTrigger attributes" do
          json_response = parse_json_response(basic_serve_call(account).body)

          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

          assert_valid_schema RackSchemas::Common::SurveySchema, json_response["survey"]

          expect(json_response["survey"]["render_after_element_clicked_enabled"]).to eq("t")
          expect(json_response["survey"]["render_after_element_clicked"]).to eq(@trigger.render_after_element_clicked)
        end
      end

      context "when a TextOnPageTrigger is defined" do
        before do
          @trigger = create(:text_on_page_trigger, text_on_page_enabled: true,
                            text_on_page_presence: true, text_on_page_selector: "#foo",
                            text_on_page_value: "bar", survey: survey)
        end

        it "returns TextOnPageTrigger attributes" do
          json_response = parse_json_response(basic_serve_call(account).body)

          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

          assert_valid_schema RackSchemas::Common::SurveySchema, json_response["survey"]

          expect(json_response["survey"]["text_on_page_enabled"]).to eq("t")
          expect(json_response["survey"]["text_on_page_presence"]).to eq("t")
          expect(json_response["survey"]["text_on_page_selector"]).to eq("#foo")
          expect(json_response["survey"]["text_on_page_value"]).to eq("bar")
        end
      end
    end

    it "returns survey attributes and submission id" do
      account = create(:account)
      setting = account.personal_data_setting
      survey = create(:survey, theme: create(:theme))
      survey.account = account
      survey.inline_target_position = Survey.inline_target_positions[:above]
      survey.save

      json_response = parse_json_response(basic_serve_call(account).body)

      assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

      assert_valid_schema RackSchemas::Common::SurveySchema, json_response["survey"]

      expect_survey_columns_to_select(json_response, survey)
      expect(json_response["survey"]["theme_css"]).to eq(survey.theme.css)
      expect(json_response["submission"]["udid"]).not_to be_nil
      expect(json_response["survey"]["pulse_insights_branding"]).to eq(survey.account.pulse_insights_branding)
      expect(json_response["survey"]["inline_target_position"].to_i).to eq(Survey.inline_target_positions[survey.inline_target_position])
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

      json_response = parse_json_response(basic_serve_call(account).body)

      expect(json_response["survey"]["survey_locale_group_id"].to_i).to eq(survey.survey_locale_group_id)
    end

    it "returns device udid" do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save

      json_response = parse_json_response(basic_serve_call(account).body)

      expect(json_response["device"]["udid"]).to eq(udid)
    end

    it "returns callback codes" do
      account = create(:account,
                       onanswer_callback_enabled: true, onanswer_callback_code: 'return onanswer_callback_code;',
                       onview_callback_enabled: true, onview_callback_code: 'return onview_callback_code;')
      create(:survey, account: account)

      json_response = parse_json_response(basic_serve_call(account).body)

      expect(json_response["survey"]["onanswer_callback_code"]).to eq(account.onanswer_callback_code)
      expect(json_response["survey"]["onview_callback_code"]).to eq(account.onview_callback_code)
    end

    describe "branding" do
      subject { @json_response["survey"]["pulse_insights_branding"] }

      let(:account) { create(:account, pulse_insights_branding: branding_enabled) }
      let(:branding_enabled) { nil }

      before do
        create(:survey, account: account)

        @json_response = parse_json_response(basic_serve_call(account).body)
      end

      context "when branding is not configured in the account" do
        it { is_expected.to be false }
      end

      context "when branding is disabled in the account" do
        let(:branding_enabled) { false }

        it { is_expected.to be false }
      end

      context "when branding is enabled in the account" do
        let(:branding_enabled) { true }

        it { is_expected.to be true }
      end
    end

    describe "disabled account" do
      before do
        account = create(:account, enabled: false)
        create(:survey, account: account)

        @response = basic_serve_call(account)
      end

      it "logs a message" do
        expect(@response.body).to include('This account has been deactivated by the administrator.')
      end

      it "does not enqueue a worker" do
        expect(Sidekiq::Queue.new.size).to eq(0)
      end
    end

    it_behaves_like "rack frequency capped serving" do
      def make_call(account, preview_mode: false)
        parse_json_response(basic_serve_call(account, parameters: { preview_mode: preview_mode }).body)
      end
    end

    it_behaves_like "rack refire limiter" do
      def make_call(account)
        parse_json_response(basic_serve_call(account).body)
      end
    end

    describe 'device_type' do
      it "does not render a mobile disabled survey on mobile" do
        account = create(:account)
        survey = create(:survey)
        survey.account = account

        # Disable survey on mobile
        survey.mobile_enabled = false
        survey.save

        # Should appear on desktop
        json_response = parse_json_response(basic_serve_call(account).body)
        assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, json_response

        # Should not appear on mobile
        json_response = parse_json_response(basic_serve_call(account, parameters: { device_type: "mobile" }).body)
        assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
      end

      it "fallbacks to the survey available for the platform" do
        account = create(:account)

        mobile_survey = create(:survey)
        mobile_survey.account = account
        mobile_survey.desktop_enabled = false
        mobile_survey.tablet_enabled = false
        mobile_survey.save

        desktop_survey = create(:survey)
        desktop_survey.account = account
        desktop_survey.mobile_enabled = false
        desktop_survey.tablet_enabled = false
        desktop_survey.save

        tablet_survey = create(:survey)
        tablet_survey.account = account
        tablet_survey.mobile_enabled = false
        tablet_survey.desktop_enabled = false
        tablet_survey.save

        # Should return the desktop survey on desktop
        json_response = parse_json_response(basic_serve_call(account).body)
        expect(json_response["survey"]["id"]).to eq(desktop_survey.id)

        # Should return the tablet survey on tablet
        json_response = parse_json_response(basic_serve_call(account, parameters: { device_type: "tablet" }).body)
        expect(json_response["survey"]["id"]).to eq(tablet_survey.id)

        # Should return the mobile survey on mobile
        json_response = parse_json_response(basic_serve_call(account, parameters: { device_type: "mobile" }).body)
        expect(json_response["survey"]["id"]).to eq(mobile_survey.id)
      end
    end

    describe "preview mode" do
      let(:preview_mode) { false }
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }

      before do
        survey.reload
      end

      describe "DRAFT survey retrieval" do
        let(:survey) { create(:survey, status: 0, account: account) }

        before do
          @json_response = parse_json_response(basic_serve_call(account, parameters: { preview_mode: preview_mode }).body)
        end

        context "when preview mode is enabled" do
          let(:preview_mode) { true }

          it "does returns surveys in DRAFT" do
            expect(@json_response["survey"]["id"].to_i).to eq(survey.id)
          end
        end

        context "when preview mode is not enabled" do
          it "does not return surveys in DRAFT" do
            assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, @json_response
          end
        end
      end
    end

    describe 'params validation' do
      subject { @response.code }

      let(:account) { create(:account) }

      let(:headers) { {} }
      let(:params) { {} }

      before do
        @response = basic_serve_call(account, parameters: params, headers: headers)
      end

      context "when the identifier has no corresponding account" do
        let(:params) { { identifier: "PI-12345678" } }

        it { is_expected.to eq "400" }
      end

      context "when the device_type is invalid" do
        let(:params) { { device_type: "garbage" } }

        it { is_expected.to eq "400" }
      end

      context "when there's no Referer in the header" do
        let(:headers) { { Referer: nil } }

        it { is_expected.to eq "400" }
      end
    end

    it_behaves_like "serve worker argument" do
      let(:device_type) { "desktop" }
      let(:survey) { create(:survey) }
    end

    describe "ServeWorker" do
      let(:survey) { create(:survey) }
      let(:account) { survey.account }
      let(:extra_parameters) { {} }
      let(:referer_url) { 'http://localhost:3000' }
      let(:device_udid) { udid }

      before do
        @device = create(:device, udid: device_udid)

        basic_serve_call(account, parameters: {client_key: client_key}.merge(extra_parameters), headers: {'Referer' => referer_url})

        queue = Sidekiq::Queue.new
        @job_arguments = queue.first["args"][0]
      end

      describe "custom_data" do
        subject { @job_arguments["custom_data"] }

        context "when no custom_data has been provided" do
          it { is_expected.to eq "{}" }
        end
      end

      describe "survey_id" do
        subject { @job_arguments["survey_id"] }

        it { is_expected.to eq survey.id }
      end

      describe "url" do
        subject { @job_arguments["url"] }

        context "when url is provided" do
          let(:extra_parameters) { { url: query_url } }
          let(:query_url) { "http://pulseinsights.com" }

          it { is_expected.to eq query_url }
        end

        context "when url is not provided" do
          it { is_expected.to eq referer_url }
        end
      end

      describe "client_key" do
        subject { @job_arguments["client_key"] }

        context "when an invalid client_key has been provided" do
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
        json_response = parse_json_response(basic_serve_call(@account, parameters: { client_key: client_key }).body)

        expect(json_response["survey"]["id"].to_i).not_to eq(0)
      end

      it 'does not render survey if different device but same client key' do
        device = create(:device, udid: udid2, client_key: client_key)
        submission = create(:submission, device_id: device.id, survey_id: @survey.id)
        create(:answer, question: @survey.reload.questions.first,
                        possible_answer: @survey.reload.questions.first.possible_answers.first,
                        submission: submission)

        json_response = parse_json_response(basic_serve_call(@account, parameters: { client_key: client_key }).body)

        assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
      end
    end

    it_behaves_like "accounts.ips_to_block-based request blocker" do
      def make_call(preview_mode)
        create(:survey, account: account)

        headers = { Referer: "http://localhost:3000", X_REAL_IP: "192.168.0.1" }

        basic_serve_call(account, parameters: { preview_mode: preview_mode }, headers: headers)
      end

      def non_blocked_response(response)
        expect(response.code).to eq "200"
        expect(parse_json_response(response.body)["survey"]).not_to be_nil
      end
    end

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        create(:survey, account: account)

        basic_serve_call(account)
      end
    end

    it_behaves_like "account verifier" do
      def make_call(identifier_param)
        create(:survey, account: create(:account))

        headers = { Referer: "http://localhost:3000" }

        url = "/serve?callback=#{callback}&" \
              "udid=#{udid}&device_type=desktop" \
              "#{identifier_param}"

        rack_app(url, headers)
      end
    end
  end

  describe 'time trigger' do
    before do
      @account = create(:account)
      survey = create(:survey)
      survey.account = @account
      survey.save

      create(:page_after_seconds_trigger, survey: survey, render_after_x_seconds_enabled: true, render_after_x_seconds: 5)
    end

    it 'returns the right values' do
      json_response = parse_json_response(basic_serve_call(@account).body)

      expect(json_response["survey"]["render_after_x_seconds"].to_i).not_to eq('5')
      expect(json_response["survey"]["render_after_x_seconds_enabled"].to_i).not_to eq('t')
    end
  end

  it_behaves_like "background image verifier" do
    def make_call(account)
      parse_json_response(basic_serve_call(account).body)
    end
  end

  it_behaves_like "rack widget trigger" do
    def make_call(account, additional_query_params: {})
      basic_serve_call(account, parameters: additional_query_params)
    end
  end

  it_behaves_like "rack geo targeting trigger" do
    def make_call(account, geotargeting_headers)
      parse_json_response(basic_serve_call(account, headers: geotargeting_headers).body)
    end
  end

  it_behaves_like "rack client key targeting" do
    def make_call(account, client_key_param)
      parse_json_response(basic_serve_call(account, parameters: client_key_param).body)
    end
  end

  it_behaves_like "rack url trigger" do
    def make_call(account, referer, url: nil)
      parameters = {}
      parameters.merge!(url: url) if url

      headers = { Referer: referer }

      parse_json_response(basic_serve_call(account, parameters: parameters, headers: headers).body)
    end
  end

  describe 'visits trigger' do
    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }

    describe 'all visitor type' do
      before do
        create(:visit_trigger, survey: survey, visitor_type: :all_visitors)
      end

      [nil, 0, 1].each do |visit_count|
        context "when visit_count = #{visit_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { visit_count: visit_count }).body)
          end

          it "returns survey" do
            assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
          end
        end
      end
    end

    describe "first time visitor" do
      before do
        create(:visit_trigger, survey: survey, visitor_type: :first_time_visitors)
      end

      [nil, 0, 1].each do |visit_count|
        context "when visit_count = #{visit_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { visit_count: visit_count }).body)
          end

          it "returns survey" do
            assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
          end
        end
      end

      [2].each do |visit_count|
        context "when visit_count = #{visit_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { visit_count: visit_count }).body)
          end

          it "does not return the survey" do
            assert_valid_schema RackSchemas::Serve::ErrorResponseSchema, @json_response
          end
        end
      end
    end

    describe "repeat visitor" do
      before do
        create(:visit_trigger, survey: survey, visitor_type: :repeat_visitors, visits_count: 1)
      end

      [nil, 0].each do |visit_count|
        context "when visit_count = #{visit_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { visit_count: visit_count }).body)
          end

          it "does not return the survey" do
            assert_valid_schema RackSchemas::Serve::ErrorResponseSchema, @json_response
          end
        end
      end

      [1].each do |visit_count|
        context "when visit_count = #{visit_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { visit_count: visit_count }).body)
          end

          it "returns survey" do
            assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
          end
        end
      end

      context "when visit_count = 0 but linked devices visit_count > 0" do
        before do
          device = create(:device, udid: udid2, client_key: client_key)
          create(:submission, device_id: device.id, survey_id: survey.id, client_key: client_key, visit_count: 1)

          @json_response = parse_json_response(basic_serve_call(account, parameters: {visit_count: 0, client_key: client_key}).body)
        end

        it "returns survey" do
          assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
        end
      end
    end
  end

  describe 'pageviews trigger' do
    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }

    context "when threshold = 0" do
      before do
        create(:pageview_trigger, survey: survey, pageviews_count: 0)
      end

      [nil, 0, 1].each do |pageview_count|
        context "when pageview_count = #{pageview_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { pageview_count: pageview_count }).body)
          end

          it "returns survey" do
            assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
          end
        end
      end
    end

    context "when threshold = 10" do
      before do
        create(:pageview_trigger, survey: survey, pageviews_count: 10)
      end

      [nil, 9].each do |pageview_count|
        context "when pageview_count = #{pageview_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { pageview_count: pageview_count }).body)
          end

          it "does not return the survey" do
            assert_valid_schema RackSchemas::Serve::ErrorResponseSchema, @json_response
          end
        end
      end

      [10, 11].each do |pageview_count|
        context "when pageview_count = #{pageview_count}" do
          before do
            @json_response = parse_json_response(basic_serve_call(account, parameters: { pageview_count: pageview_count }).body)
          end

          it "returns survey" do
            assert_valid_schema RackSchemas::Serve::SuccessfulResponseSchema, @json_response
          end
        end
      end
    end
  end

  describe 'ResolvePageEventsWorker' do
    let(:account) { create(:account) }

    context 'when there is an enabled url type automation that belongs to the account' do
      it 'fires the worker' do
        create(:automation_with_condition_and_action, condition_type: :url, action_type: :create_event, account: account)
        expect { basic_serve_call(account) }.to change { Sidekiq::Queue.new.size }.from(0).to(1)
        expect(Sidekiq::Queue.new.first['class']).to eq 'ResolvePageEventsWorker'
      end
    end

    context 'when there is a disabled url type automation that belongs to the account' do
      it 'does not fire the worker' do
        create(:automation_with_condition_and_action, enabled: false, condition_type: :url, action_type: :create_event, account: account)
        expect { basic_serve_call(account) }.not_to change { Sidekiq::Queue.new.size }
      end
    end

    context 'when there is an enabled answer_text type automation that belongs to the account' do
      it 'does not fire the worker' do
        create(:automation_with_condition_and_action, account: account)
        expect { basic_serve_call(account) }.not_to change { Sidekiq::Queue.new.size }
      end
    end

    context 'when there is an enabled url type automation that does not belong to the account' do
      it 'does not fire the worker' do
        create(:automation_with_condition_and_action, enabled: false, condition_type: :url, action_type: :create_event)
        expect { basic_serve_call(account) }.not_to change { Sidekiq::Queue.new.size }
      end
    end
  end

  # Calls the endpoint with the required parameters and headers
  def basic_serve_call(account, parameters: {}, headers: {})
    query = {
      callback: callback,
      udid: udid,
      device_type: "desktop",
      identifier: account.identifier
    }.merge(parameters).to_query

    headers = { Referer: "http://localhost:3000" }.merge(headers)

    rack_app("/serve?#{query}", headers)
  end
end
