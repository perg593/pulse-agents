# frozen_string_literal: true

require 'spec_helper'

describe Auth::RegistrationsController do
  let(:email) { 'test@testing.com' }
  let(:boilerplate_params) do
    {
      first_name: 'John', last_name: 'Smith',
      email: email, password: 'Password123!'
    }
  end

  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all
  end

  describe "POST #create" do
    context "with an expired invitation" do
      before do
        user_params = boilerplate_params.merge!(invite_token: invitation.token)

        post :create, params: { user: user_params }
      end

      context "with an expiration date in the past" do
        let(:invitation) { create(:invitation, expires_at: 1.day.ago) }

        it "does not create a user" do
          expect(User.count).to eq(0)
        end
      end
    end

    context "with an invitation" do
      before do
        user_params = boilerplate_params.merge!(invite_token: invitation.token)

        post :create, params: { user: user_params }
      end

      context "with full access" do
        let(:invitation) { create(:invitation) }

        it "creates a user linked to the invitation account with the correct user level" do
          expect(User.count).to eq(1)

          user = User.last
          expect(user.email).to eq(email)
          expect(user.account_id).to eq(invitation.account_id)
          expect(user.level).to eq('full')
        end

        context "with a mixed-case e-mail" do
          let(:email) { 'TEST@testing.COM' }

          it 'downcases the email' do
            expect(User.count).to eq(1)
            expect(User.last.email).to eq(email.downcase)
          end
        end
      end

      context "with reporting-only" do
        let(:invitation) { create(:reporting_only_invitation) }

        it "creates a user linked to the invitation account with the correct user level" do
          expect(User.count).to eq(1)

          user = User.last
          expect(user.email).to eq(email)
          expect(user.account_id).to eq(invitation.account_id)
          expect(user.level).to eq('reporting')
        end
      end
    end

    context "without an invitation" do
      before do
        user_params = boilerplate_params.merge!(
          account_attributes: { name: FFaker::Company.name }
        )

        post :create, params: { user: user_params }
      end

      it "creates a full access user and a new account" do
        expect(User.count).to eq(1)

        user = User.last
        expect(user.email).to eq(email)
        expect(user.level).to eq('full')

        expect(Account.count).to eq(1)
        expect(user.account_id).to eq(Account.last.id)
      end
    end
  end
end
