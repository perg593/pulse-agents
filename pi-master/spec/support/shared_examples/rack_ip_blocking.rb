# frozen_string_literal: true

# Shared examples for a rack endpoint that implements ip address-based request blocking
RSpec.shared_examples "accounts.ips_to_block-based request blocker" do
  let(:ips_to_block) { "" }
  let(:account) { create(:account, ips_to_block: ips_to_block) }
  let(:preview_mode) { false }

  # The rack endpoint call. We provide the Account, you provide the setup
  # Perform the call to the rack app along with any other endpoint-specific db setup
  # Include X_REAL_IP: "192.168.0.1" in the headers
  #
  # @param { bool } preview_mode - Whether or not preview mode is active
  # @return { Net::HTTPResponse } The response
  def make_call(preview_mode)
    raise NotImplementedError, "You must implement 'make_call' to use 'accounts.ips_to_block-based request blocker'"
  end

  # Confirm that the response was a "IP address blocked" response.
  # Maybe check for side effects too, if you want.
  #
  # @param { Net::HTTPResponse } response - the response from the rack app.
  def non_blocked_response(response)
    raise NotImplementedError, "You must implement 'non_blocked_response' to use 'accounts.ips_to_block-based request blocker'"
  end

  before do
    @response = make_call(preview_mode)
  end

  context "when IP address of request does not match blocked IP address" do
    let(:ips_to_block) { "192.168.0.2" }

    it "renders the survey" do
      non_blocked_response(@response)
    end
  end

  context "when IP address of request matches blocked IP address exactly" do
    let(:ips_to_block) { "192.168.0.1" }

    it "does not render survey" do
      assert_blocked_response
    end

    context "when preview_mode is active" do
      let(:preview_mode) { true }

      it "renders the survey" do
        non_blocked_response(@response)
      end
    end
  end

  context "when IP address of request matches blocked IP address by regex" do
    let(:ips_to_block) { "/192.168.0.*/" }

    it "does not render survey" do
      assert_blocked_response
    end
  end

  context "when IP address of request matches blocked one of many IP addresses exactly" do
    let(:ips_to_block) { "192.168.0.3\n192.168.0.2\n192.168.0.1" }

    it "does not render survey" do
      assert_blocked_response
    end
  end

  context "when IP address of request matches blocked one of many IP addresses via regex" do
    let(:ips_to_block) { "/192.168.0.*/\n/192.168.1.*/\n/192.168.2.*/" }

    it "does not render survey" do
      assert_blocked_response
    end
  end

  context "when no IP blocklist is defined" do
    let(:ips_to_block) { nil }

    it "renders the survey" do
      non_blocked_response(@response)
    end
  end

  context "when IP blocklist is an empty string" do
    let(:ips_to_block) { "" }

    it "renders the survey" do
      non_blocked_response(@response)
    end
  end

  private

  def assert_blocked_response
    expect(@response.code).to eq("200")
    expect(@response.body).to include "window.PulseInsightsObject.log(\"IP 192.168.0.1 not allowed\")"
  end
end
