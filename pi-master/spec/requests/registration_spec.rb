# frozen_string_literal: true
require 'spec_helper'

describe "Registration" do
  describe 'session[:from_invitation]' do
    subject { session[:from_invitation] }

    let(:invite_token) { nil }
    let(:email_address) { nil }

    before do
      params = {
        invite_token: invite_token,
        email: email_address
      }
      get '/sign_up', params: params
    end

    context 'when invite_token is not provided' do
      let(:invite_token) { nil }

      it { is_expected.to eq 'no' }
    end

    context 'when email is not provided' do
      let(:email_address) { nil }

      it { is_expected.to eq 'no' }
    end

    context 'when invite_token and email are provided' do
      let(:email_address) { invitation.email }
      let(:invitation) { create(:invitation) }

      context 'with an Invitation with an Account' do
        let(:invite_token) { invitation.token }

        it { is_expected.to eq 'yes' }
      end

      context 'with no associated Invitation' do
        let(:invite_token) { 'someFakeToken' }

        it { is_expected.to eq 'no' }
      end

      context 'with the wrong email address' do
        let(:invite_token) { invitation.token }
        let(:email_address) { FFaker::Internet.email }

        it { is_expected.to eq 'no' }
      end
    end
  end
end
