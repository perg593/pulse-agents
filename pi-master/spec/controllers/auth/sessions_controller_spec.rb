# frozen_string_literal: true
require 'spec_helper'

describe Auth::SessionsController do
  describe "GET #new" do
    render_views

    it "is able to render the login page" do
      get :new
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 if Google is browsing the site with the image/* accept header" do
      request.env["HTTP_ACCEPT"] = "image/*"
      get :new
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET initiate_saml" do
    let(:idp_config) do
      {
        issuer: 'https://console.pulseinsights.com',
        idp_sso_service_url: 'idp_url',
        idp_entity_id: 'idp_entity_id',
        idp_cert: 'idp_certificate',
        assertion_consumer_service_url: 'https://console.pulseinsights.com/auth/saml/:idp_id/callback',
        sp_identity_id: 'sp_identity_id',
        idp_sso_service_binding: "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
        name_identifier_format: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      }
    end

    context "when the provided e-mail address matches that of an existing user with an IdP set up" do
      let(:user) { create(:user) }

      before do
        Account.any_instance.stub(:idp_set_up?).and_return(true) # rubocop:disable RSpec/AnyInstance
        Account.any_instance.stub(:idp_config).and_return(idp_config) # rubocop:disable RSpec/AnyInstance
      end

      it "redirects the user to the account's IdP signin page" do
        get :initiate_saml, params: { email: user.email }
        assert_response 302
        expect(response.headers["Location"]).to include idp_config[:idp_sso_service_url]
      end

      context 'when the passed email is case insensitive having capitalized letters' do
        it "redirects the user to the account's IdP signin page" do
          get :initiate_saml, params: { email: user.email.upcase }

          assert_response 302
          expect(response.headers["Location"]).to include idp_config[:idp_sso_service_url]
        end
      end
    end

    context "when the provided e-mail address does not match any existing user" do
      before do
        get :initiate_saml, params: { email: FFaker::Internet.email }
      end

      it "redirects the user back to the signin page" do
        assert_redirected_to sign_in_url
      end
    end

    context "when the associated user has no IdP configured" do
      before do
        user = create(:user)
        Account.any_instance.stub(:idp_set_up?).and_return(false) # rubocop:disable RSpec/AnyInstance

        get :initiate_saml, params: { email: user.email }
      end

      it "redirects the user back to the signin page" do
        assert_redirected_to sign_in_url
      end
    end
  end
end
