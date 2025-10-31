# frozen_string_literal: true
require 'spec_helper'

describe "Oauth" do
  # TODO: This isn't entirely appropriate for an integration test.
  # Consider testing whether they reached the desired page or some other outcome of
  # being signed in successfully
  def signed_in?
    request.env['warden'].authenticated?(:user)
  end

  let!(:user) { create(:user) }

  context "when someone logs in via Google" do
    it_behaves_like "omniauth" do
      let(:provider) { :google_oauth2 }
    end
  end

  context "when someone logs in via Google SAML" do
    let(:provider) { :saml }
    let(:idp_identifier) { :comcast }

    context "with a Pulse Insights account" do
      before do
        OmniAuth.config.add_mock(provider, { info: { email: user.email } })
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

        post "/auth/saml/#{idp_identifier}/callback"
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
        OmniAuth.config.add_mock(provider, { info: { email: FFaker::Internet.email } })
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

        post "/auth/saml/#{idp_identifier}/callback"
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
        OmniAuth.config.add_mock(provider, { info: { email: user.email } })
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

        user.update(active: false)

        post "/auth/saml/#{idp_identifier}/callback"
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
        OmniAuth.config.add_mock(provider, { info: { email: user.email } })
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

        user.lock_access!

        post "/auth/saml/#{idp_identifier}/callback"
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

  context "when someone with an account logs in via an unsupported provider" do
    let(:provider) { :twitter }

    before do
      OmniAuth.config.add_mock(provider, { info: { email: user.email } })
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      get "/auth/#{provider}/callback"
    end

    it "does not log the user in" do
      expect(signed_in?).to be false
    end

    it "redirects the visitor to the signin page" do
      assert_redirected_to sign_in_url
    end
  end

  context "when request.env['omniauth.auth'] is empty" do
    let(:provider) { :saml }
    let(:idp_identifier) { :comcast }

    before do
      OmniAuth.config.add_mock(provider, { info: { email: user.email } })
      Rails.application.env_config["omniauth.auth"] = nil

      post "/auth/saml/#{idp_identifier}/callback"
    end

    it 'redirects to sign-in url' do
      assert_redirected_to sign_in_url
    end
  end
end
