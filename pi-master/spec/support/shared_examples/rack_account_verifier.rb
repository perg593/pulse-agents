# frozen_string_literal: true

# Shared examples for a rack endpoint that implements account identifier verification
# - presence of parameter
# - validity of parameter
RSpec.shared_examples "account verifier" do
  def make_call(identifier_param)
    raise NotImplementedError, "You must implement 'make_call' to use 'account verifier'"
    # e.g.
    # account = create(:account)
    # survey = create(:survey, account: account)
    # udid = SecureRandom.udid
    # callback = 'window.PulseInsightsObject.jsonpCallbacks.request_0'
    #
    # url = "/serve?identifer=#{account.identifier}&device_type=desktop&callback=#{callback}&udid=#{udid}" \
    # headers = { Referer: "http://localhost:3000" }
    #
    # rack_app(url, headers)
  end

  ["", "&identifier=PI-1234567"].each do |invalid_identifier|
    context "with multiple values ->#{invalid_identifier}<-" do
      before do
        @response = make_call(invalid_identifier)
      end

      it "returns an error" do
        expect(@response.code).to eq "400"
      end

      it "returns a plaintext response" do
        expect(@response["Content-Type"]).to eq "text/plain"
      end

      it "returns an error message" do
        expect(@response.body).to eq "Error: Parameter 'identifier' missing"
      end
    end
  end
end
