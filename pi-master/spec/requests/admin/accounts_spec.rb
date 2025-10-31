# frozen_string_literal: true
require 'spec_helper'

describe 'Accounts' do
  describe "GET #edit" do
    let(:account) { create(:account) }

    context "when the user is not signed in" do
      before do
        get edit_admin_account_path(account)
      end

      it "redirects to the sign-in page" do
        assert_redirected_to sign_in_url
      end
    end

    context "when the user is signed in" do
      before do
        post '/users/sign_in', params: { user: { email: user.email, password: user.password } }
      end

      context "when the user is not an admin" do
        let(:user) { create(:user, account: account) }

        before do
          get edit_admin_account_path(account)
        end

        it "redirects to the dashboard page" do
          assert_redirected_to dashboard_url
        end
      end

      context "when the user is an admin" do
        let(:user) { create(:admin, account: account) }

        before do
          account.update(viewed_impressions_enabled_at: 1.month.ago)

          survey = create(:survey, account: account)

          create(:survey_submission_cache, survey: survey, viewed_impression_count: 10, submission_count: 5,
                 applies_to_date: account.viewed_impressions_enabled_at + 1.day)
          create(:survey_submission_cache, survey: survey, viewed_impression_count: 15, submission_count: 10,
                 applies_to_date: account.viewed_impressions_enabled_at + 2.day)
          create(:survey_submission_cache, survey: survey, viewed_impression_count: 20, submission_count: 15,
                 applies_to_date: account.viewed_impressions_enabled_at + 3.days)

          get edit_admin_account_path(account)
        end

        it "displays the account's submission stats" do
          render_template :edit

          assert_select '.impression_count', text: 'Impressions : 45'
          assert_select '.submission_count', text: 'Submissions : 30'
        end
      end
    end
  end
end
