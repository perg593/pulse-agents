# frozen_string_literal: true
require 'spec_helper'

describe "Auth::PasswordController" do
  let(:user) { create(:user) }

  describe "new" do
    before do
      get "/users/password/new"
    end

    it "renders the password reset form" do
      expect(response.body).to include("Reset Password")
    end
  end

  describe "edit" do
    context "when a reset_password_token is provided" do
      let(:reset_password_token) { SecureRandom.hex(10) }

      before do
        get "/users/password/edit", params: { reset_password_token: reset_password_token }
      end

      it "renders the password edit form" do
        expect(response.body).to include("Change your password")
        expect(response.body).to include(reset_password_token)
      end
    end
  end

  describe "update" do
    let(:new_password) { "abcDEF123!@#" }

    before do
      @token_digest = user.send_reset_password_instructions
    end

    context "when the user is not locked" do
      before do
        put "/users/password", params: { user: { reset_password_token: @token_digest, password: new_password, password_confirmation: new_password } }
      end

      it "resets the user's password to the password provided" do
        expect(user.reload.valid_password?(new_password)).to be true
      end

      it "renders the signin page" do
        assert_redirected_to root_url
        expect(flash[:notice]).to include("Your password has been changed successfully")
      end
    end

    context "when the user is locked" do
      before do
        user.lock_access!

        put "/users/password", params: { user: { reset_password_token: @token_digest, password: new_password, password_confirmation: new_password } }
      end

      it "unlocks the user" do
        expect(user.reload.access_locked?).to be false
      end
    end

    context "when reset_password_token is absent" do
      before do
        put "/users/password", params: { user: { password: new_password, password_confirmation: new_password } }
      end

      it "does not reset the user's password" do
        expect(user.reload.valid_password?(new_password)).to be false
      end
    end

    # TODO: Understand why this fails
    # context "when the password and confirmation password don't match" do
    #   before do
    #     put "/users/password", params: { user: { reset_password_token: @token_digest, password: new_password, password_confirmation: "wrong password" } }
    #   end
    #
    #   it "does not reset the user's password" do
    #     expect(user.reload.valid_password?(new_password)).to be false
    #   end
    # end
  end

  describe "password reset" do
    let(:user) { create(:user) }

    before do
      post "/users/password", params: { user: { email: user.email } }
    end

    it "sends an email" do
      expect(UserMailer.deliveries.count).to eq 1

      email = UserMailer.deliveries.first

      expect(email.subject).to eq "[Pulse Insights] Reset your password"
      expect(email.to).to eq([user.email])
      expect(email.cc).to eq(["alerts@pulseinsights.com"])
      expect(email.bcc).to eq(["ops@pulseinsights.com"])

      expect(email.body).to include("Change my password")
      expect(email.body).to include(edit_user_password_path)
    end

    it "sets a reset_token" do
      expect(user.reload.reset_password_token).not_to be_nil
      expect(user.reset_password_sent_at).to be_within(1.minute).of(Time.current)
    end

    it "renders the signin page" do
      assert_redirected_to new_user_session_path
    end
  end
end
