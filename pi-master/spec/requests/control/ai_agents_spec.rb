# frozen_string_literal: true
require 'spec_helper'

describe 'Control::AIAgentsController' do
  include Devise::Test::IntegrationHelpers

  describe "#edit" do
    context "when the user is not signed in" do
      it "redirects to the sign in page" do
        get edit_ai_agents_path

        assert_redirected_to sign_in_url
      end
    end

    context "when the user is signed in" do
      let(:user) { create(:user) }

      before do
        sign_in(user)

        get edit_ai_agents_path
      end

      # TODO: How to test meaningfully?
      it "renders the edit page" do
        expect(response).to have_http_status(:ok)
      end

      context "when the user is a report-only user" do
        let(:user) { create(:reporting_only_user) }

        it "redirects to the dashboard" do
          assert_redirected_to dashboard_url
        end
      end
    end
  end

  describe "#update" do
    context "when the user is not signed in" do
      it "redirects to the sign in page" do
        patch ai_agents_path

        assert_redirected_to sign_in_url
      end
    end

    context "when the user is signed in" do
      let(:user) { create(:user) }

      before do
        sign_in(user)

        # TODO: Add agents to toggle
        patch ai_agents_path, params: { }
      end

      it "redirects to the edit page" do
        assert_redirected_to edit_ai_agents_path
      end

      # TODO: implement agents to toggle
      # it "updates the account" do
      # end

      context "when the user is a report-only user" do
        let(:user) { create(:reporting_only_user) }

        it "redirects to the dashboard" do
          assert_redirected_to dashboard_url
        end
      end
    end
  end
end
