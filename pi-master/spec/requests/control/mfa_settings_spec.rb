# frozen_string_literal: true
require 'spec_helper'

describe 'Control::MFASettingsController' do
  let(:user) { create(:user) }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: user.password } }
  end

  describe "#new" do
    context "when the user has MFA active" do
      before do
        user.activate_mfa!
        get '/mfa_settings/new'
      end

      it "redirects back" do
        expect(response).to redirect_to(edit_my_account_path)
      end
    end

    context "when the user does not have MFA active" do
      before do
        get '/mfa_settings/new'
      end

      context "when the user has no otp_secret" do
        it "assigns an otp_secret to the current user" do
          expect(user.reload.otp_secret).to be_present
        end
      end

      context "when the user has an otp_secret" do
        let(:user) { create(:user, otp_secret: User.generate_otp_secret) }
        let(:old_otp_secret) { user.otp_secret }

        it "does not overwrite the existing otp_secret" do
          expect(user.otp_secret).to eq(old_otp_secret)
        end
      end
    end
  end

  describe "#create" do
    let(:user) { create(:user, otp_secret: User.generate_otp_secret) }

    context "when the user does not have MFA active" do
      context "when the password matches the current user's password and the code is a valid otp code" do
        before do
          otp_code = user.otp(user.otp_secret).at(Time.now)

          post '/mfa_settings', params: { password: user.password, code: otp_code }
        end

        it "enables MFA for the user" do
          user.reload

          expect(user.otp_required_for_login).to be true
        end

        it "redirects to #edit" do
          expect(response).to redirect_to(edit_mfa_settings_path)
        end
      end

      context "when the password does not match the current user's password" do
        before do
          otp_code = user.otp(user.otp_secret).at(Time.now)

          post '/mfa_settings', params: { password: "wrong password", code: otp_code }
        end

        it "does not enable MFA for the user" do
          user.reload

          expect(user.otp_required_for_login).to be false
        end
      end

      context "when the code is not a valid otp code" do
        before do
          post '/mfa_settings', params: { password: user.password, code: "wrong code" }
        end

        it "does not enable MFA for the user" do
          user.reload

          expect(user.otp_required_for_login).to be false
        end
      end
    end

    context "when the user has MFA active" do
      before do
        user.activate_mfa!
        otp_code = user.otp(user.otp_secret).at(Time.now)

        post '/mfa_settings', params: { password: user.password, code: otp_code }
      end

      it "redirects them back" do
        expect(response).to redirect_to(edit_my_account_path)
      end
    end
  end

  describe "#edit" do
    context "when the user has MFA active" do
      before do
        user.activate_mfa!
        get '/mfa_settings/edit'
      end

      context "when the user has no backup codes" do
        it "generates backup codes" do
          expect(user.reload.otp_backup_codes.count).to be 5
        end
      end

      context "when the user has backup codes" do
        before do
          user.generate_otp_backup_codes!
          user.save
          @old_backup_codes = user.otp_backup_codes
        end

        it "does not generate backup codes" do
          expect(user.reload.otp_backup_codes).to eq(@old_backup_codes)
        end
      end
    end

    context "when the user does not have MFA active" do
      before do
        get '/mfa_settings/edit'
      end

      it "redirects them to #new" do
        expect(response).to redirect_to(new_mfa_settings_path)
      end
    end
  end

  describe "#destroy" do
    before do
      user.activate_mfa!

      delete '/mfa_settings'
    end

    it "disables MFA for the user" do
      user.reload

      expect(user.otp_required_for_login).to be false
      expect(user.otp_secret).to be_nil
      expect(user.otp_backup_codes).to be_nil
    end

    it "redirects to #my_account/edit" do
      expect(response).to redirect_to(edit_my_account_path)
    end
  end
end
