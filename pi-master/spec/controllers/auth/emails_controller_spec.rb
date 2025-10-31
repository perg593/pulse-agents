# frozen_string_literal: true
require 'spec_helper'

describe Auth::EmailsController do
  describe 'PATCH #update' do
    let(:original_email) { FFaker::Internet.email }
    let(:new_email) { FFaker::Internet.email }
    let(:reset_email_token) { SecureRandom.hex(10) }
    let!(:user) { create(:user, email: original_email, reset_email_token: reset_email_token, reset_email_sent_at: Time.current) }

    context "when the token doesn't match" do
      before do
        patch :update, params: { user: { reset_email_token: SecureRandom.hex(10), new_email: new_email, password: user.password } }
      end

      it "does not update the user's email" do
        expect(user.reload.email).to eq original_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:alert]).to eq "Sorry, couldn't find your user"
      end
    end

    context "when the authentication has failed" do
      before do
        patch :update, params: { user: { reset_email_token: reset_email_token, new_email: new_email, password: 'wrong password' } }
      end

      it "does not update the user's email" do
        expect(user.reload.email).to eq original_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:alert]).to eq "Sorry, couldn't verify you"
      end
    end

    context "when the confirmation email has been expired" do
      before do
        user.update(reset_email_sent_at: 1.day.ago)
        patch :update, params: { user: { reset_email_token: reset_email_token, new_email: new_email, password: user.password } }
      end

      it "does not update the user's email" do
        expect(user.reload.email).to eq original_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:alert]).to eq "Sorry, the confirmation email has expired"
      end
    end

    context "when the new email is not in the valid email format" do
      before do
        patch :update, params: { user: { reset_email_token: reset_email_token, new_email: 'invalid email', password: user.password } }
      end

      it "does not update the user's email" do
        expect(user.reload.email).to eq original_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:alert]).to eq "Sorry, failed to update your email"
      end
    end

    context "when the new email already exists" do
      before do
        create(:user, email: new_email)
        patch :update, params: { user: { reset_email_token: reset_email_token, new_email: new_email, password: user.password } }
      end

      it "does not update the user's email" do
        expect(user.reload.email).to eq original_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:alert]).to eq "Sorry, failed to update your email"
      end
    end

    context "when the tokens match, the confirmation email hasn't expired and the new email is valid" do
      before do
        post :update, params: { user: { reset_email_token: reset_email_token, new_email: new_email, password: user.password } }
      end

      it "updates the email" do
        expect(user.reload.email).to eq new_email
      end

      it "redirects to sign-in page" do
        expect(response).to redirect_to sign_in_url
        expect(flash[:notice]).to eq 'Email successfully updated!'
      end
    end
  end
end
