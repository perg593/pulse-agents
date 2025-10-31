# frozen_string_literal: true
require 'spec_helper'
require_relative "../../lib/qrvey_client/qrvey_client"

describe QrveyClient do
  let(:qrvey_user_id) { "i9-pTgwzF" }
  let(:application_schema_stub) do
    {
      name: "My very first application",
      userid: "v23-pTgwzF",
      appid: "3v3oi"
    }
  end
  let(:column_schema_stub) do
    {
      "origColumnSourceName" => 'a',
      "columnId" => 'a',
      "datasetId" => 'a'
    }
  end
  let(:dataset_schema_stub) do
    {
      "columns" => [column_schema_stub, column_schema_stub]
    }
  end
  let(:stubbed_headers) do
    {
      'Content-Type'=>'application/json',
      'Host'=>'phbxd.qrveyapp.com',
      'X-Api-Key'=>'api_key_placeholder'
    }
  end
  let(:qrvey_app_id) { "KuvOXfLiZ" }
  let(:qrvey_dashboard_id) { "fmFP78SJg" }

  shared_examples "sophisticated error handling" do
    let(:qrvey_error_sample) { {"status"=>"error", "date"=>1713373451, "errors"=>[{"message"=>"ValidationError: name is a required property but has no value when trying to save item", "messageDetails"=>true, "stack"=>"Error: ValidationError: name is a required property but has no value when trying to save item\n    at PageModel.updatePage (/var/task/lib/pageModel.js:425:23)\n    at process.processTicksAndRejections (node:internal/process/task_queues:95:5)\n    at async PageModel.manageUpdating (/var/task/lib/pageModel.js:795:29)\n    at async updatePageByPageId (/var/task/controller/pageController.js:159:33)"}]} }

    [400, 401, 500].each do |error_code|
      context "when a #{error_code} response is returned" do
        before do
          stub_request(:any, /.*/).to_return(status: error_code, body: qrvey_error_sample.to_json)
        end

        it "raises an error with the expected message" do
          errors = qrvey_error_sample["errors"]
          expected_error_messages = errors.map { |error| error["message"] }.join(",")

          expect { call_qrvey }.to raise_error(QrveyClient::HTTP::QrveyError, expected_error_messages)
        end
      end
    end
  end

  shared_examples "logging" do
    context "when no logger is specified" do
      it "writes logs with Rails.logger" do
        expect(Rails.logger).to receive(:<<).at_least(:once)

        method.call(*args)
      end
    end

    context "when a logger is specified" do
      before do
        @logger = Logger.new("tmp/foo")
      end

      it "writes logs with specified logger" do
        expect(@logger).to receive(:<<).at_least(:once)

        method.call(*args, logger: @logger)
      end
    end
  end

  describe "#create_application" do
    let(:stubbed_body) { { "test" => "structure" } }
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/user/#{qrvey_user_id}/app" }

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(body: stubbed_body, headers: stubbed_headers).
                           to_return(status: 200, body: application_schema_stub.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:create_application) }
        let(:args) { [qrvey_user_id, stubbed_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.create_application(qrvey_user_id, stubbed_body) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.create_application(qrvey_user_id, stubbed_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a Qrvey app ID" do
        expect(@response["appid"]).not_to be_nil
      end
    end
  end

  describe "#create_user" do
    let(:stubbed_body) { { "test" => "structure" } }
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/core/user" }
    let(:mock_qrvey_user_id) { "i9-pTgwzF" }

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(body: stubbed_body, headers: stubbed_headers).
                           to_return(status: 200, body: "{\"userid\": \"#{mock_qrvey_user_id}\"}", headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:create_user) }
        let(:args) { [stubbed_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.create_user(stubbed_body) }
      end
    end

    describe "happy path" do
      before do
        @qrvey_user_id = described_class.create_user(stubbed_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a Qrvey user ID" do
        expect(@qrvey_user_id).to eq mock_qrvey_user_id
      end
    end
  end

  describe "#generate_token" do
    let(:stubbed_body) { { "test" => "structure" } }
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/core/login/token" }
    let(:mock_token) { "placeholder_token" }

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(body: stubbed_body, headers: stubbed_headers).
                           to_return(status: 200, body: "{\"token\": \"#{mock_token}\"}", headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:generate_token) }
        let(:args) { [stubbed_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.generate_token(stubbed_body) }
      end
    end

    describe "happy path" do
      before do
        @token = described_class.generate_token(stubbed_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "can generate a Qrvey token" do
        expect(@token).to eq mock_token
      end
    end
  end

  describe "#share_application" do
    let(:stubbed_body) { { "test" => "structure" } }
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/user/#{qrvey_user_id}/app/share" }

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(body: stubbed_body, headers: stubbed_headers).
                           to_return(status: 200, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:share_application) }
        let(:args) { [qrvey_user_id, stubbed_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.share_application(qrvey_user_id, stubbed_body) }
      end
    end

    describe "happy path" do
      before do
        @response_value = described_class.share_application(qrvey_user_id, stubbed_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns true" do
        expect(@response_value).to be true
      end
    end
  end

  describe "#get_published_dashboards" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/history/publishednow" }

    before do
      @qrvey_api_request = stub_request(:get, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: {"Items" => [{"pageOriginalid" => qrvey_dashboard_id}]}.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_published_dashboards) }
        let(:args) { [qrvey_user_id, qrvey_app_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.get_published_dashboards(qrvey_user_id, qrvey_app_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_published_dashboards(qrvey_user_id, qrvey_app_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      # TODO: Define the structure
      it "returns a structure which contains Qrvey dashboard IDs" do
        expect(@response["Items"][0]["pageOriginalid"]).to eq qrvey_dashboard_id
      end
    end
  end

  describe "#get_dataset" do
    let(:qrvey_dataset_id) { "fmFP78SJg" }
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}/qollect/dataset/#{qrvey_dataset_id}" }
    let(:mock_survey_column_id) { "foo" }

    before do
      stubbed_body = dataset_schema_stub
      stubbed_body["columns"].last["origColumnSourceName"] = "survey_id"
      stubbed_body["columns"].last["columnId"] = mock_survey_column_id

      @qrvey_api_request = stub_request(:get, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_dataset) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dataset_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.get_dataset(qrvey_user_id, qrvey_app_id, qrvey_dataset_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_dataset(qrvey_user_id, qrvey_app_id, qrvey_dataset_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains Qrvey column IDs" do
        survey_id_column = @response["columns"].detect { |column| column["origColumnSourceName"] == "survey_id" }

        expect(survey_id_column["columnId"]).to eq mock_survey_column_id
      end
    end
  end

  describe "#get_all_datasets" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v4/user/#{qrvey_user_id}/app/#{qrvey_app_id}/qollect/dataset/all" }
    let(:mock_qrvey_dataset_id) { "foo" }

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(headers: stubbed_headers).
                           with(body: {}.to_json).
                           to_return(status: 200, body: {"Items" => [{"datasetId" => mock_qrvey_dataset_id}]}.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_all_datasets) }
        let(:args) { [qrvey_user_id, qrvey_app_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.get_all_datasets(qrvey_user_id, qrvey_app_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_all_datasets(qrvey_user_id, qrvey_app_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      # TODO: Define the structure
      it "returns a structure which contains Qrvey dataset IDs" do
        expect(@response["Items"][0]["datasetId"]).to eq mock_qrvey_dataset_id
      end
    end
  end

  describe "#get_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}" }
    let(:stubbed_body) { { "test" => "structure" } }

    before do
      @qrvey_api_request = stub_request(:get, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dashboard_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.get_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end
    end
  end

  describe "#create_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/" }
    let(:stubbed_dashboard_id) { "abc123" }
    let(:stubbed_dashboard_name) { "Quarterly Insights" }
    let(:stubbed_dashboard_description) { "A simple test dashboard" }
    let(:stubbed_response_body) { { "pageid" => stubbed_dashboard_id }.merge(stubbed_request_body) }
    let(:stubbed_request_body) do
      {
        "name" => stubbed_dashboard_name,
        "description" => stubbed_dashboard_description
      }
    end

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:create_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, stubbed_request_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.create_dashboard(qrvey_user_id, qrvey_app_id, stubbed_request_body) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.create_dashboard(qrvey_user_id, qrvey_app_id, stubbed_request_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains a Qrvey dashboard ID" do
        expect(@response["pageid"]).to eq stubbed_dashboard_id
        expect(@response["name"]).to eq stubbed_dashboard_name
        expect(@response["description"]).to eq stubbed_dashboard_description
      end
    end
  end

  describe "#clone_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}/clone" }
    let(:stubbed_dashboard_id) { "abc123" }
    let(:stubbed_dashboard_name) { "New Quarterly Insights" }
    let(:stubbed_asset_prefix) { "new" }
    let(:stubbed_response_body) { { "pageid" => stubbed_dashboard_id, "pageName" => stubbed_dashboard_name } }
    let(:stubbed_request_body) do
      {
        "pageName" => stubbed_dashboard_name,
        "prefix" => stubbed_asset_prefix
      }
    end

    before do
      @qrvey_api_request = stub_request(:post, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:clone_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, stubbed_request_body] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.clone_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, stubbed_request_body) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.clone_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, stubbed_request_body)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains the clone dashboard's ID" do
        expect(@response["pageid"]).to eq stubbed_dashboard_id
        expect(@response["pageName"]).to eq stubbed_dashboard_name
      end
    end
  end

  describe "#delete_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}" }
    let(:stubbed_response_message) { "Page successfully deleted" }
    let(:stubbed_response_body) { { "message" => stubbed_response_message } }

    before do
      @qrvey_api_request = stub_request(:delete, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:delete_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dashboard_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.delete_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.delete_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains a message explaining the result" do
        expect(@response["message"]).to eq stubbed_response_message
      end
    end
  end

  describe "#update_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/#{qrvey_dashboard_id}" }
    let(:stubbed_request_body) { { "published" => true } }

    let(:stubbed_response_body) { { "published" => true } }

    before do
      @qrvey_api_request = stub_request(:put, qrvey_url).
                           with(body: stubbed_request_body, headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:update_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true}] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.update_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true}) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.update_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true})
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains the published status" do
        expect(@response["published"]).to be true
      end
    end
  end

  describe "#patch_dashboard" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v6/page/builder/#{qrvey_dashboard_id}?userId=#{qrvey_user_id}&appId=#{qrvey_app_id}" }
    let(:stubbed_request_body) { { "published" => true } }

    let(:stubbed_response_body) { { "published" => true } }

    before do
      @qrvey_api_request = stub_request(:patch, qrvey_url).
                           with(body: stubbed_request_body, headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response_body.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:patch_dashboard) }
        let(:args) { [qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true}] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.patch_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true}) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.patch_dashboard(qrvey_user_id, qrvey_app_id, qrvey_dashboard_id, {published: true})
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      it "returns a structure which contains the published status" do
        expect(@response["published"]).to be true
      end
    end
  end

  describe "#get_all_dashboards" do
    let(:qrvey_url) { "https://phbxd.qrveyapp.com/devapi/v3/user/#{qrvey_user_id}/app/#{qrvey_app_id}/builder/page/" }

    before do
      @qrvey_api_request = stub_request(:get, qrvey_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: {"Items" => [{"pageOriginalid" => qrvey_dashboard_id}]}.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_all_dashboards) }
        let(:args) { [qrvey_user_id, qrvey_app_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_qrvey) { described_class.get_all_dashboards(qrvey_user_id, qrvey_app_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_all_dashboards(qrvey_user_id, qrvey_app_id)
      end

      it "makes a request to Qrvey" do
        expect(@qrvey_api_request).to have_been_requested
      end

      # TODO: Define the structure
      it "returns a structure which contains Qrvey dashboard IDs" do
        expect(@response["Items"][0]["pageOriginalid"]).to eq qrvey_dashboard_id
      end
    end
  end
end
