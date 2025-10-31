# frozen_string_literal: true
require 'spec_helper'
require_relative "../../lib/gamma_client/gamma_client"

describe GammaClient do
  let(:generation_id) { "gen_123456789" }
  let(:gamma_url) { "https://gamma.app/docs/abc123def456" }
  let(:stubbed_headers) do
    {
      'X-API-KEY' => 'api_key_placeholder',
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  shared_examples "sophisticated error handling" do
    let(:gamma_error_sample) { {"message" => "Invalid API key.", "statusCode" => 401} }

    [400, 401, 404, 422, 429, 500, 502].each do |error_code|
      context "when a #{error_code} response is returned" do
        before do
          stub_request(:any, /.*/).to_return(status: error_code, body: gamma_error_sample.to_json)
        end

        it "raises an error with the expected message" do
          expected_error_message = case error_code
          when 400
            "Bad Request: Invalid API key."
          when 401
            "Unauthorized: Invalid API key"
          when 404
            "Not Found: Invalid API key."
          when 422
            "Generation failed: Invalid API key."
          when 429
            "Rate limit exceeded. Please retry later."
          when 500
            "Internal server error. Please contact support."
          when 502
            "Bad gateway. Please try again."
          else
            "Unexpected error (#{error_code}): Invalid API key."
          end

          expect { call_gamma }.to raise_error(GammaClient::HTTP::GammaError, expected_error_message)
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

  describe "#generate_gamma" do
    let(:gamma_url) { "https://public-api.gamma.app/v0.2/generations" }
    let(:stubbed_body) do
      {
        textMode: "preserve",
        cardOptions: { dimensions: "16x9" },
        sharingOptions: { workspaceAccess: "fullAccess", externalAccess: "edit" },
        imageOptions: { source: "noImages" }
      }
    end
    let(:stubbed_response) { { "generationId" => generation_id } }

    before do
      @gamma_api_request = stub_request(:post, gamma_url).
                           with(body: stubbed_body, headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:generate_gamma) }
        let(:args) { [] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_gamma) { described_class.generate_gamma }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.generate_gamma
      end

      it "makes a request to Gamma API" do
        expect(@gamma_api_request).to have_been_requested
      end

      it "returns a generation ID" do
        expect(@response).to eq generation_id
      end
    end

    context "with custom parameters" do
      let(:custom_body) do
        {
          textMode: "preserve",
          cardOptions: { dimensions: "16x9" },
          sharingOptions: { workspaceAccess: "fullAccess", externalAccess: "edit" },
          inputText: "Custom outline content",
          format: "document",
          numCards: "5",
          cardSplit: "manual",
          imageOptions: { source: "unsplash", model: "dall-e-3", style: "minimal lineart" }
        }
      end

      before do
        @custom_request = stub_request(:post, gamma_url).
                          with(body: custom_body, headers: stubbed_headers).
                          to_return(status: 200, body: stubbed_response.to_json, headers: {})
      end

      it "sends custom parameters correctly" do
        described_class.generate_gamma(
          input_text: "Custom outline content",
          format: "document",
          num_cards: "5",
          card_split: "manual",
          image_options: { source: "unsplash", model: "dall-e-3", style: "minimal lineart" }
        )

        expect(@custom_request).to have_been_requested
      end

      it "uses API defaults when optional parameters are not provided" do
        # Add a stub for the default case
        default_request = stub_request(:post, gamma_url).
                          with(
                            body: {
                              textMode: "preserve",
                              cardOptions: { dimensions: "16x9" },
                              sharingOptions: { workspaceAccess: "fullAccess", externalAccess: "edit" },
                              inputText: "Custom outline content",
                              imageOptions: { source: "noImages" }
                            },
                            headers: stubbed_headers
                          ).
                          to_return(status: 200, body: stubbed_response.to_json, headers: {})

        described_class.generate_gamma(
          input_text: "Custom outline content"
        )

        expect(default_request).to have_been_requested
      end
    end
  end

  describe "#get_generation_status" do
    let(:gamma_url) { "https://public-api.gamma.app/v0.2/generations/#{generation_id}" }
    let(:stubbed_response) do
      {
        "generationId" => generation_id,
        "status" => "completed",
        "gammaUrl" => gamma_url
      }
    end

    before do
      @gamma_api_request = stub_request(:get, gamma_url).
                           with(headers: stubbed_headers).
                           to_return(status: 200, body: stubbed_response.to_json, headers: {})
    end

    describe "logging" do
      it_behaves_like "logging" do
        let(:method) { described_class.method(:get_generation_status) }
        let(:args) { [generation_id] }
      end
    end

    describe "unhappy path" do
      it_behaves_like "sophisticated error handling" do
        let(:call_gamma) { described_class.get_generation_status(generation_id) }
      end
    end

    describe "happy path" do
      before do
        @response = described_class.get_generation_status(generation_id)
      end

      it "makes a request to Gamma API" do
        expect(@gamma_api_request).to have_been_requested
      end

      it "returns generation status information" do
        expect(@response["generationId"]).to eq generation_id
        expect(@response["status"]).to eq "completed"
        expect(@response["gammaUrl"]).to eq gamma_url
      end
    end

    context "when generation is still processing" do
      let(:processing_response) do
        {
          "generationId" => generation_id,
          "status" => "processing"
        }
      end

      before do
        @processing_request = stub_request(:get, gamma_url).
                              with(headers: stubbed_headers).
                              to_return(status: 200, body: processing_response.to_json, headers: {})
      end

      it "returns processing status" do
        response = described_class.get_generation_status(generation_id)
        expect(response["status"]).to eq "processing"
        expect(response["gammaUrl"]).to be_nil
      end
    end
  end

  describe "#generation_completed?" do
    let(:gamma_url) { "https://public-api.gamma.app/v0.2/generations/#{generation_id}" }

    context "when generation is completed" do
      let(:completed_response) do
        {
          "generationId" => generation_id,
          "status" => "completed",
          "gammaUrl" => gamma_url
        }
      end

      before do
        stub_request(:get, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 200, body: completed_response.to_json, headers: {})
      end

      it "returns true" do
        expect(described_class.generation_completed?(generation_id)).to be true
      end
    end

    context "when generation is still processing" do
      let(:processing_response) do
        {
          "generationId" => generation_id,
          "status" => "processing"
        }
      end

      before do
        stub_request(:get, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 200, body: processing_response.to_json, headers: {})
      end

      it "returns false" do
        expect(described_class.generation_completed?(generation_id)).to be false
      end
    end

    context "when API call fails" do
      before do
        stub_request(:get, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 404, body: { "message" => "Generation ID not found" }.to_json, headers: {})
      end

      it "returns false" do
        expect(described_class.generation_completed?(generation_id)).to be false
      end
    end
  end

  describe "#get_gamma_url" do
    let(:gamma_url) { "https://public-api.gamma.app/v0.2/generations/#{generation_id}" }

    context "when generation is completed" do
      let(:completed_response) do
        {
          "generationId" => generation_id,
          "status" => "completed",
          "gammaUrl" => gamma_url
        }
      end

      before do
        stub_request(:get, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 200, body: completed_response.to_json, headers: {})
      end

      it "returns the gamma URL" do
        expect(described_class.get_gamma_url(generation_id)).to eq gamma_url
      end
    end

    context "when generation is still processing" do
      let(:processing_response) do
        {
          "generationId" => generation_id,
          "status" => "processing"
        }
      end

      before do
        stub_request(:get, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 200, body: processing_response.to_json, headers: {})
      end

      it "returns nil" do
        expect(described_class.get_gamma_url(generation_id)).to be_nil
      end
    end
  end

  describe "error handling edge cases" do
    let(:gamma_url) { "https://public-api.gamma.app/v0.2/generations" }

    context "when API returns malformed JSON" do
      before do
        stub_request(:post, gamma_url).
          with(headers: stubbed_headers).
          to_return(status: 500, body: "Invalid JSON response", headers: {})
      end

      it "handles malformed JSON gracefully" do
        expect do
          described_class.generate_gamma
        end.to raise_error(GammaClient::HTTP::GammaError, /Internal server error/)
      end
    end

    context "when network connection fails" do
      before do
        stub_request(:post, gamma_url).
          with(headers: stubbed_headers).
          to_raise(SocketError.new("Connection failed"))
      end

      it "returns nil and logs the error" do
        expect(Rails.logger).to receive(:error).with(/Gamma API connection error/)
        expect(described_class.generate_gamma).to be_nil
      end
    end
  end
end
