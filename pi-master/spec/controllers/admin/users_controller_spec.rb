# frozen_string_literal: true
require 'spec_helper'

describe Admin::UsersController do
  before do
    Account.delete_all
    User.delete_all
    AccountUser.delete_all
    Invitation.delete_all

    @user = create(:admin)
    @account = create(:account)
  end

  describe "PATCH #update" do
    it "updates the user level to reporting" do
      @another_user = create(:user)
      expect(@another_user.level).to eq('full')

      sign_in @user

      patch :update, params: { id: @another_user.id, user: {level: "1"}, format: :json }

      expect(@another_user.reload.level).to eq('reporting')
      expect(response.body).to eq('"ok"')
    end

    it "updates the user level to full" do
      @another_user = create(:reporting_only_user)
      expect(@another_user.level).to eq('reporting')

      sign_in @user

      response = patch :update, params: { id: @another_user.id, user: {level: "0"}, format: :json }

      expect(@another_user.reload.level).to eq('full')
      expect(response.body).to eq('"ok"')
    end

    it "does not be allowed to edit our own level" do
      sign_in @user

      patch :update, params: { id: @user.id, user: {level: "1"}, format: :json }

      expect(@user.reload.level).to eq('full')
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET #login_as' do
    it 'creates a SigninActivity record' do
      login_as_user = create(:user)

      sign_in @user
      expect { get :login_as, params: { id: login_as_user.id } }.to change { SigninActivity.count }.from(0).to(1)

      signin_activity = SigninActivity.first
      expect(signin_activity.user).to eq login_as_user
      expect(signin_activity.sudoer).to eq @user
    end
  end

  describe 'POST #add_account_link' do
    it 'creates a link between an account and a user' do
      sign_in @user
      old_num_accounts = @user.accounts.count

      post :add_account_link, params: { id: @user.id, account_name: @account.autocomplete_name }
      expect(@user.accounts.count).to eq(old_num_accounts + 1)
    end

    it 'does not create duplicate links between an account and a user' do
      sign_in @user
      old_num_accounts = @user.accounts.count

      post :add_account_link, params: { id: @user.id, account_name: @account.autocomplete_name }
      expect(@user.accounts.count).to eq(old_num_accounts + 1)

      post :add_account_link, params: { id: @user.id, account_name: @account.autocomplete_name }
      expect(@user.accounts.count).to eq(old_num_accounts + 1)
    end
  end

  describe 'DELETE #remove_account_link' do
    it 'destroys a link between an account and a user' do
      sign_in @user

      delete :remove_account_link, params: { id: @user.id, account_id: @user.account.id }
      expect(AccountUser.count).to eq(0)
    end
  end

  describe 'activate/deactivate' do
    before do
      sign_in login_user
    end

    describe 'PATCH #activate' do
      let(:subject_user) { create(:reporting_only_user, active: false, last_sign_in_at: 1.year.ago) }

      context 'with admin user logged in' do
        let(:login_user) { create(:admin) }

        it 'activates the subject user' do
          patch :activate, params: { id: subject_user.id }

          expect(subject_user.reload.active).to be true
        end

        it 'updates last sign in time' do
          current_time = Time.current
          allow(Time).to receive(:current).and_return(current_time)

          patch :activate, params: { id: subject_user.id }

          expect(subject_user.reload.last_sign_in_at.to_date).to eq current_time.to_date
        end

        it 'does not activate itself' do
          login_user.update active: false
          patch :activate, params: { id: login_user.id }

          expect(login_user.reload.active).to be false
        end
      end

      context 'with non-admin user logged in' do
        let(:login_user) { create(:reporting_only_user) }

        it 'does not activate the subject user' do
          patch :activate, params: { id: subject_user.id }

          expect(subject_user.reload.active).to be false
        end
      end
    end

    describe 'PATCH #deactivate' do
      let(:subject_user) { create(:reporting_only_user, active: true) }

      context 'with admin user logged in' do
        let(:login_user) { create(:admin) }

        it 'deactivates the subject user' do
          patch :deactivate, params: { id: subject_user.id }

          expect(subject_user.reload.active).to be false
        end

        it 'does not deactivate itself' do
          patch :deactivate, params: { id: login_user.id }

          expect(login_user.reload.active).to be true
        end
      end

      context 'with non-admin user logged in' do
        let(:login_user) { create(:reporting_only_user) }

        it 'does not deactivate the subject user' do
          patch :deactivate, params: { id: subject_user.id }

          expect(subject_user.reload.active).to be true
        end
      end
    end
  end
end
