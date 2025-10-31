# frozen_string_literal: true

# Shared examples for a rack endpoint that implements disabled account verification
RSpec.shared_examples "disabled account verifier" do
  let(:account) { create(:account, enabled: enabled) }
  let(:enabled) { nil }

  # The rack endpoint call. We provide the Account, you provide the setup
  # Perform the call to the rack app along with any other endpoint-specific db setup
  #
  # @param { Account } account - The account, which is either enabled or disabled
  # @return { Net::HTTPResponse } The response
  def make_call(account)
    raise NotImplementedError, "You must implement 'make_call' to use disabled account verifier'"
  end

  before do
    @response = make_call(account)
  end

  context "when the account is enabled" do
    let(:enabled) { true }

    it "returns code 200" do
      expect(@response.code).to eq("200")
    end

    it "does not return an error message" do
      expect(@response.body).not_to include("deactivated")
    end
  end

  context "when the account is disabled" do
    let(:enabled) { false }

    it "returns code 200" do
      expect(@response.code).to eq("200")
    end

    it "returns an error message" do
      expect(@response.body).to include("\"This account has been deactivated by the administrator.\"")
    end
  end
end
