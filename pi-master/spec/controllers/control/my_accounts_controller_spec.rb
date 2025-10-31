# frozen_string_literal: true
require 'spec_helper'

describe Control::MyAccountsController do
  include Devise::TestHelpers

  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all

    @user = create(:user)
  end

  describe "PATCH #invite" do
    it_behaves_like "invitation endpoints" do
      let(:valid_params) { { invitation: { email: FFaker::Internet.email, level: "1", account_id: @user.account_id } } }
      let(:acting_user) { @user }
      let(:account_for_invitation) { @user.account }
    end

    it "cannot invite a user to an account not belonging to inviter" do
      sign_in @user
      new_email = FFaker::Internet.email

      other_account = create(:account)
      post :invite, params: { invitation: { email: new_email, level: User.levels["full"], account_id: other_account.id } }

      expect(Invitation.count).to eq(0)
    end
  end

  describe "PATCH #update_email" do
    before do
      UserMailer.deliveries.clear
    end

    context "when the user isn't logged in" do
      it 'does not send a confirmation email' do
        patch :update_email
        expect(response).to redirect_to sign_in_url
        expect(UserMailer.deliveries.count).to eq 0
      end
    end

    context "when the user is logged in" do
      let(:original_email) { FFaker::Internet.email }
      let(:old_reset_email_token) { SecureRandom.hex(10) }

      before do
        @user.update(email: original_email, reset_email_token: old_reset_email_token)
        sign_in @user
        patch :update_email, params: { user: { email: FFaker::Internet.email } }
      end

      it 'updates their email token' do
        expect(@user.reload.reset_email_token).not_to eq old_reset_email_token
      end

      it 'sends a confirmation email' do
        expect(UserMailer.deliveries.last.subject).to include 'Reset your email'
        expect(UserMailer.deliveries.last.to).to eq [original_email]
      end
    end
  end

  describe "PATCH #update_password" do
    context "when the user isn't logged in" do
      it 'redirects to sign in page' do
        patch :update_password
        expect(response).to redirect_to sign_in_url
      end
    end

    context "when the user didn't provide the correct current password" do
      it 'renders the edit page again' do
        sign_in @user
        patch :update_password, params: { user: { current_password: 'wrong password', new_password: 'new password'} }
        expect(response).to render_template :edit
      end
    end

    context 'when the user provided the correct password' do
      # These passwords are hardcoded so they never fail the password validations
      let(:current_password) { 'Secure$1' }
      let(:new_password) { 'Secure$2' }

      let(:user) { create(:user, password: current_password, password_confirmation: current_password) }

      before do
        sign_in user
        patch :update_password, params: { user: { current_password: current_password, new_password: new_password} }
      end

      it 'updates the password' do
        expect(BCrypt::Password.new(user.reload.encrypted_password)).to eq new_password
      end

      it 'logs the user out' do
        expect(response).to redirect_to sign_in_url
      end
    end
  end

  describe "GET #data_integrations" do
    it "displays the data integration page to full access users" do
      sign_in @user
      get :data_integrations

      expect(response).to have_http_status(:ok)
    end

    it "does not display the data integration page to reporting only users" do
      User.delete_all
      sign_in create(:reporting_only_user)
      get :data_integrations
      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end
  end

  describe "GET #user_management" do
    it "displays the user management page to full access users" do
      sign_in @user
      get :user_management

      expect(response).to have_http_status(:ok)
    end

    it "does not display the user management page to reporting only users" do
      User.delete_all
      sign_in create(:reporting_only_user)
      get :user_management
      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end
  end

  describe "PATCH #set_user_level" do
    it "updates the user level to reporting" do
      @another_user = create(:user, email: 'anotheremail@test.com', account: @user.account)
      expect(@another_user.level).to eq('full')

      sign_in @user

      patch :set_user_level, params: { id: @another_user.id, user: {level: "1"}, format: :json }

      expect(@another_user.reload.level).to eq('reporting')
      expect(response.body).to eq('"ok"')
    end

    it "updates the user level to full" do
      @another_user = create(:reporting_only_user, account: @user.account)
      expect(@another_user.level).to eq('reporting')

      sign_in @user

      response = patch :set_user_level, params: { id: @another_user.id, user: {level: "0"}, format: :json }

      expect(@another_user.reload.level).to eq('full')
      expect(response.body).to eq('"ok"')
    end

    it "does not be allowed to a reporting only user" do
      User.delete_all
      sign_in create(:reporting_only_user)

      @user = create(:user)
      expect(@user.level).to eq('full')

      response = patch :set_user_level, params: { id: @user.id, user: {level: "1"}, format: :json }

      expect(@user.reload.level).to eq('full')
      expect(response.status).to eq(302)
    end

    it "does not be allowed to edit the level of another user from another account" do
      @another_user = create(:user, email: 'anotheremail@test.com')
      expect(@another_user.level).to eq('full')

      sign_in @user

      patch :set_user_level, params: { id: @another_user.id, user: {level: "1"}, format: :json }

      expect(@another_user.reload.level).to eq('full')
      expect(response).to have_http_status(:not_found)
    end

    it "does not be allowed to edit our own level" do
      sign_in @user

      patch :set_user_level, params: { id: @user.id, user: {level: "1"}, format: :json }

      expect(@user.reload.level).to eq('full')
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH #update" do
    let(:new_account_name) { FFaker::Lorem.word }

    before do
      @old_account_name = user.account.name

      sign_in user

      patch :update, params: { id: user.account.id, user: { account_name: new_account_name }, type: "info" }
    end

    context "when the user is not an administrator" do
      let(:user) { create(:user) }

      it "returns 200" do
        assert_response 200
      end

      it "does not change the account name" do
        expect(user.account.reload.name).to eq @old_account_name
      end

      it "shows an error message" do
        expect(flash[:alert]).to eq "Only superadmins may edit account names. Please contact support@pulseinsights.com"
      end
    end

    context "when the user is an administrator" do
      let(:user) { create(:admin) }

      it "returns 200" do
        assert_response 200
      end

      it "changes the account name" do
        expect(user.account.reload.name).to eq new_account_name
      end
    end
  end

  describe "PATCH #update_global_targeting" do
    let(:account) { create(:account) }

    describe 'User permissions' do
      let(:allowed_domains) { "test.com\ntest.uk\r\ntest.ca" }

      context "when the user isn't signed in" do
        before do
          patch :update_global_targeting, params: { account: { domains_to_allow_for_redirection: allowed_domains } }
        end

        it "redirects to the sign-in page" do
          assert_redirected_to sign_in_url
        end

        it 'does not update the account' do
          expect(account.domains_to_allow_for_redirection).to eq []
        end
      end

      context 'with a reporting-only user' do
        let(:user) { create(:reporting_only_user, account: account) }

        before do
          sign_in user

          patch :update_global_targeting, params: { account: { domains_to_allow_for_redirection: allowed_domains } }
        end

        it "redirects to the survey index page" do
          assert_redirected_to dashboard_url
        end

        it "does not update the account" do
          expect(account.domains_to_allow_for_redirection).to eq []
        end
      end

      context 'with a full user' do
        before do
          sign_in create(:user, account: account)

          patch :update_global_targeting, params: { account: { domains_to_allow_for_redirection: allowed_domains } }
        end

        it "redirects to the global targeting page" do
          assert_redirected_to global_targeting_my_account_url
        end

        it 'updates the account' do
          expect(account.reload.domains_to_allow_for_redirection).to eq allowed_domains.split(/\r?\n/)
        end
      end
    end

    describe 'Invalid input' do
      it 'does not update the account' do
        sign_in create(:user, account: account)

        invalid_domain_input = 'test.com test.uk test.ca' # Joined with white spaces, not newlines
        patch :update_global_targeting, params: { account: { domains_to_allow_for_redirection: invalid_domain_input } }

        expect(response).to redirect_to(global_targeting_my_account_url)
        expect(flash[:alert]).to include 'Failed to update global targeting'
        expect(account.reload.domains_to_allow_for_redirection).to eq []
      end
    end
  end
end
