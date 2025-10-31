# frozen_string_literal: true
require 'spec_helper'

describe Admin::AccountsController do
  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all

    @user = create(:admin)
    @account = create(:account)
  end

  describe "Account requirement" do
    it "redirects to the survey dashboard when the account is not found" do
      sign_in @user

      endpoints = [
        { verb: :patch, url: :activate },
        { verb: :get, url: :audit },
        { verb: :patch, url: :deactivate },
        { verb: :delete, url: :destroy },
        { verb: :get, url: :edit },
        { verb: :patch, url: :observe },
        { verb: :patch, url: :update }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end
  end

  # TODO: Apply the authentication/authorization testing across the controller
  describe "GET #fetch_submissions" do
    context "when the user is not signed in" do
      it "redirects to the sign-in page" do
        create(:user)
        get :fetch_submissions
        assert_response 302
        assert_redirected_to sign_in_url
      end
    end

    context "when the user is not an admin" do
      it "redirects to the dashboard page" do
        sign_in create(:user)
        get :fetch_submissions
        assert_response 302
        assert_redirected_to dashboard_url
      end
    end

    it "returns stats for each account" do
      3.times do
        (1..10).each do |n|
          create(:survey_submission_cache, survey: create(:survey), impression_count: 10 * n, viewed_impression_count: 7 * n, submission_count: 5 * n)
        end
      end

      sign_in create(:admin)
      get :fetch_submissions

      json_response.each do |account_stats|
        account = Account.find(account_stats['account_id'].to_i)
        impression_size = account.surveys.sum(&:cached_blended_impressions_count)
        submission_size = account.submission_caches.sum(&:submission_count)
        expect(account_stats['impressions_size']).to eq impression_size
        expect(account_stats['submissions_size']).to eq submission_size
      end
    end
  end

  describe "PATCH #invite" do
    it_behaves_like "invitation endpoints" do
      let(:valid_params) { { invitation: { email: FFaker::Internet.email, level: "1", account_id: @account.id } } }
      let(:acting_user) { @user }
      let(:account_for_invitation) { @account }
    end

    it "is not available to non-admin users" do
      account = create(:account)
      user = create(:user, account: account)
      new_email = FFaker::Internet.email

      sign_in user

      post :invite, params: { invitation: {email: new_email, level: "1", account_id: @account.id} }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it "is available to admins regardless of account ID" do
      sign_in @user
      account = create(:account)
      new_email = FFaker::Internet.email

      post :invite, params: { invitation: {email: new_email, level: "1", account_id: account.id} }

      expect(Invitation.count).to eq(1)
      expect(Invitation.first.account_id).to eq(account.id)
      expect(Invitation.first.email).to eq(new_email)
      expect(Invitation.first.level).to eq(1)
    end

    it "works when the primary user has switched their account" do
      base_account = create(:account)

      primary_user = create(:user, account: base_account)
      other_account = create(:account)
      primary_user.accounts << other_account
      primary_user.switch_accounts(other_account.id)

      admin_user = create(:admin, account: base_account)

      test_email = FFaker::Internet.email

      sign_in admin_user

      post :invite, params: { invitation: {email: test_email, level: "1", account_id: base_account.id} }

      expect(Invitation.count).to eq(1)
      expect(Invitation.first.account_id).to eq(base_account.id)
      expect(Invitation.first.email).to eq(test_email)
      expect(Invitation.first.level).to eq(1)
    end
  end

  describe 'PATCH #observe' do
    it 'updates the account record based on params[:is_observed]' do
      sign_in @user
      patch :observe, params: { id: @account.id, is_observed: 'true' }
      expect(@account.reload.is_observed?).to be true
    end
  end

  describe 'PATCH #update' do
    context 'when a user is non admin' do
      it "doesn't allow to edit" do
        sign_in create(:user, account: @account)
        expect { patch :update, params: { id: @account.id, account: { tag_automation_enabled: '1' } } }.
          not_to change { @account.reload.tag_automation_enabled }
      end
    end

    context 'when a user is admin' do
      it 'allows to edit' do
        sign_in create(:admin, account: @account)
        expect { patch :update, params: { id: @account.id, account: { tag_automation_enabled: '1' } } }.
          to change { @account.reload.tag_automation_enabled }.from(false).to(true)
      end
    end
  end
end
