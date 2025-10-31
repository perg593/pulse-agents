# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper
include Rack::Database

require File.join(File.dirname(__FILE__), "schemas", "present_event_schema")

describe Rack::PresentEvent do
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
  let(:pseudo_event_name) { "clicked-feedback-link" }

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      survey = create(:survey, account: account)
      create(:pseudo_event_trigger, survey: survey, pseudo_event: pseudo_event_name)

      basic_present_event_call(account)
    end
  end

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      survey = create(:survey, account: create(:account))
      create(:pseudo_event_trigger, survey: survey, pseudo_event: pseudo_event_name)

      url = "/surveys/#{pseudo_event_name}?callback=#{callback}&" \
            "udid=#{udid}&device_type=desktop" \
            "#{identifier_param}"

      headers = { Referer: "http://localhost:3000" }

      rack_app(url, headers)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account)
      create(:pseudo_event_trigger, survey: survey, pseudo_event: pseudo_event_name)

      headers = { Referer: "http://localhost:3000", X_REAL_IP: "192.168.0.1" }

      basic_present_event_call(account, parameters: { preview_mode: preview_mode }, extra_headers: headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      expect(parse_json_response(response.body)["survey"]).not_to be_nil
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier, :device_type, :callback, :udid], "/surveys/clicked-feedback-link" do
    let(:optional_defaults) { { device_type: "desktop" } }
  end

  describe '/surveys/event-name' do
    describe "response validation" do
      let(:account) { create(:account) }
      let(:device_type) { "desktop" }

      before do
        survey = create(:survey, account: account)
        create(:pseudo_event_trigger, survey: survey, pseudo_event: pseudo_event_name)

        @response = basic_present_event_call(account, parameters: { device_type: device_type })
      end

      context "when successful" do
        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::PresentEvent::SuccessfulResponseSchema, json_response
        end
      end

      context "when unsuccessful" do
        let(:device_type) { nil }

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::PresentEvent::ErrorResponseSchema, @response.body
        end
      end
    end

    it "returns a response of type application/javascript" do
      account = create(:account)
      survey = create(:survey, account: account)
      create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)

      expect(basic_present_event_call(account)['Content-Type']).to eq('application/javascript')
    end

    it "returns 400 if the callback parameter is tainted" do
      survey = create(:survey)
      create(:pseudo_event_trigger, survey: survey, pseudo_event: survey.name)

      tainted_callback = 'eval(document.cookies)'
      response = rack_app("/surveys/#{survey.name}&callback=#{tainted_callback}/" \
                          "udid=00000000-0000-4000-f000-000000000000&device_type=desktop", 'Referer' => 'http://localhost:3000')

      expect(response.code).to eq("400")
    end

    describe "preview mode" do
      let(:preview_mode) { false }
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }

      before do
        create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)

        @json_response = parse_json_response(basic_present_event_call(account, parameters: { preview_mode: preview_mode }).body)
      end

      describe "DRAFT survey retrieval" do
        let(:survey) { create(:survey, status: :draft, account: account) }

        context "when preview mode is enabled" do
          let(:preview_mode) { true }

          it "does returns surveys in DRAFT" do
            expect(@json_response["survey"]["id"].to_i).to eq(survey.id)
          end
        end

        context "when preview mode is not enabled" do
          it "does not return surveys in DRAFT" do
            expect(@json_response["survey"]).to be_nil
          end
        end
      end

      # Frequency caps have no effect on present_event
      describe "frequency_caps behaviour" do
        let(:account) { create(:account, frequency_cap_enabled: true, frequency_cap_type: 'hours', frequency_cap_limit: 1, frequency_cap_duration: 2) }

        before do
          device = create(:device, udid: udid)
          create(:submission, device_id: device.id, survey_id: survey.id, created_at: 30.minutes.ago)
        end

        context "when preview mode is enabled" do
          let(:preview_mode) { true }

          it "returns surveys which have exceeded their frequency_cap" do
            expect(@json_response["survey"]["id"].to_i).to eq(survey.id)
          end
        end

        context "when preview mode is not enabled" do
          it "returns surveys which have exceeded their frequency_cap" do
            expect(@json_response["survey"]["id"].to_i).to eq(survey.id)
          end
        end
      end
    end

    describe "ServeWorker" do
      let(:account) { create(:account) }
      let(:referer_url) { "http://localhost:3000" }
      let(:extra_parameters) { {} }
      let(:device_type) { "desktop" }
      let(:device_udid) { udid }

      before do
        survey = create(:survey, account: account)
        create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)
        survey.save

        @device = create(:device, udid: device_udid)

        basic_present_event_call(account, parameters: extra_parameters)

        queue = Sidekiq::Queue.new
        @job_arguments = queue.first["args"][0]
      end

      def expected_worker_keys
        %w(
          custom_data
          device_id
          device_type
          identifier
          ip_address
          pageview_count
          pseudo_event
          submission_udid
          survey_id
          udid
          url
          user_agent
          visit_count
        )
      end

      it "queues ServeWorker" do
        queue = Sidekiq::Queue.new

        job_class = queue.first["class"]
        expect(job_class).to eq("ServeWorker")
      end

      it "queues ServeWorker with the expected arguments" do
        expect(@job_arguments.keys).to match_array(expected_worker_keys)
      end

      describe "identifier" do
        subject { @job_arguments["identifier"] }

        it { is_expected.to eq account.identifier }
      end

      describe "submission_udid" do
        subject { @job_arguments["submission_udid"] }

        it { is_expected.not_to be_nil }
      end

      describe "device_id" do
        subject { @job_arguments["device_id"] }

        context "when device associated with provided udid exists" do
          let(:device_udid) { udid }

          it { is_expected.to eq @device.id.to_s }
        end

        context "when device associated with provided udid does not exist" do
          let(:device_udid) { "00000000-0000-4000-f000-000000000002" }

          it { is_expected.to be_nil }
        end
      end

      describe "udid" do
        subject { @job_arguments["udid"] }

        it { is_expected.to eq udid }
      end

      describe "url" do
        subject { @job_arguments["url"] }

        context "when url is provided" do
          let(:extra_parameters) { {url: query_url} }
          let(:query_url) { "http://pulseinsights.com" }

          it { is_expected.to eq query_url }
        end

        context "when url is not provided" do
          it { is_expected.to eq referer_url }
        end
      end

      describe "ip_address" do
        subject { @job_arguments["ip_address"] }

        it { is_expected.to be_nil } # Test environment won't have an IP address
      end

      describe "user_agent" do
        subject { @job_arguments["user_agent"] }

        it { is_expected.to eq "Ruby" }
      end

      describe "custom_data" do
        subject { @job_arguments["custom_data"] }

        context "when custom_data has been provided" do
          let(:custom_data) { { a: '3', b: 'foobar' } }
          let(:extra_parameters) { {custom_data: custom_data.to_json} }

          it { is_expected.to eq custom_data.to_json }
        end

        context "when custom_data has not been provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "device_type" do
        subject { @job_arguments["device_type"] }

        it { is_expected.to eq "desktop" }
      end

      describe "visit_count" do
        subject { @job_arguments["visit_count"] }

        context "when visit_count is provided" do
          let(:extra_parameters) { {visit_count: 42} }

          it { is_expected.to eq 42 }
        end

        context "when visit_count is not provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "pageview_count" do
        subject { @job_arguments["pageview_count"] }

        context "when pageview_count is provided" do
          let(:extra_parameters) { {pageview_count: 42} }

          it { is_expected.to eq 42 }
        end

        context "when pageview_count is not provided" do
          it { is_expected.to be_nil }
        end
      end

      describe "pseudo_event" do
        subject { @job_arguments["pseudo_event"] }

        it { is_expected.to eq pseudo_event_name }
      end
    end

    it "returns survey and submission attributes" do
      account = create(:account)
      setting = account.personal_data_setting
      survey = create(:survey, theme: create(:theme))
      survey.account = account
      create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)
      survey.save

      json_response = parse_json_response(basic_present_event_call(account).body)

      assert_valid_schema RackSchemas::PresentEvent::SuccessfulResponseSchema, json_response
      assert_valid_schema RackSchemas::Common::PresentEventSurveySchema, json_response["survey"]

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
      survey = create(:survey, account: account)
      create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)

      json_response = parse_json_response(basic_present_event_call(account).body)

      expect(json_response["survey"]["onanswer_callback_code"]).to eq(account.onanswer_callback_code)
      expect(json_response["survey"]["onview_callback_code"]).to eq(account.onview_callback_code)
    end

    it "sets branding to off if it's set to off in the account level" do
      account = create(:account)
      account.pulse_insights_branding = false
      account.save
      survey = create(:survey, account: account)
      create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)

      json_response = parse_json_response(basic_present_event_call(account).body)

      expect(json_response["survey"]["pulse_insights_branding"]).to be(false)

      account.pulse_insights_branding = true
      account.save

      json_response = parse_json_response(basic_present_event_call(account).body)

      expect(json_response["survey"]["pulse_insights_branding"]).to be(true)
    end

    context "when account is disabled" do
      before do
        account = create(:account, enabled: false)
        survey = create(:survey, account: account)
        create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: survey)

        @response = basic_present_event_call(account)
      end

      it "logs a message" do
        expect(@response.body).to include("This account has been deactivated by the administrator.")
      end

      it "does not enqueue a worker" do
        expect(Sidekiq::Queue.new.size).to eq(0)
      end
    end

    it_behaves_like "background image verifier" do
      def make_call(account)
        create(:pseudo_event_trigger, pseudo_event: pseudo_event_name, survey: account.surveys.first)

        parse_json_response(basic_present_event_call(account).body)
      end
    end
  end

  # Calls the endpoint with the required parameters and headers
  def basic_present_event_call(account, parameters: {}, extra_headers: {})
    query = {
      callback: callback,
      udid: udid,
      device_type: "desktop",
      identifier: account.identifier
    }.merge(parameters).to_query

    headers = { Referer: "http://localhost:3000" }.merge(extra_headers)

    rack_app("/surveys/#{pseudo_event_name}?#{query}", headers)
  end
end
