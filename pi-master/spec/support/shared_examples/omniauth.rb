# frozen_string_literal: true

RSpec.shared_examples "omniauth" do
  # requires a "provider" variable, which should be a symbol.
  # e.g. :google_oauth2, :facebook

  context "with a Pulse Insights account" do
    before do
      OmniAuth.config.add_mock(provider, {info: { email: user.email }})
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      get "/auth/#{provider}/callback"
    end

    it "logs the user in" do
      expect(signed_in?).to be true
      expect(controller.warden.user).to eq user
    end

    it "redirects the visitor to the dashboard" do
      assert_redirected_to dashboard_url
    end
  end

  context "with no Pulse Insights account" do
    before do
      OmniAuth.config.add_mock(provider, {info: { email: FFaker::Internet.email }})
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      get "/auth/#{provider}/callback"
    end

    it "does not log the user in" do
      expect(signed_in?).to be false
    end

    it "redirects the visitor to the signin page" do
      assert_response 302
      expect(response).to redirect_to(:sign_in)
      expect(flash[:alert]).to eq("We did not find a Pulse Insights account associated with this email. Please contact support@pulseinsights.com")
    end
  end

  context "with an inactive Pulse Insights account" do
    before do
      OmniAuth.config.add_mock(provider, {info: { email: user.email }})
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      user.update(active: false)

      get "/auth/#{provider}/callback"
    end

    it "does not log the user in" do
      expect(signed_in?).to be false
    end

    it "redirects the visitor to the signin page" do
      assert_response 302
      expect(response).to redirect_to(:sign_in)
      expect(flash[:alert]).to eq("This account is deactivated. Please contact support to reactivate it.")
    end
  end

  context "with a locked Pulse Insights account" do
    before do
      OmniAuth.config.add_mock(provider, {info: { email: user.email }})
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      user.lock_access!

      get "/auth/#{provider}/callback"
    end

    it "does not log the user in" do
      expect(signed_in?).to be false
    end

    it "redirects the visitor to the signin page" do
      assert_response 302
      expect(response).to redirect_to(:sign_in)
      expect(flash[:alert]).to eq("You have been locked out for too many failed password attempts.")
    end
  end
end
