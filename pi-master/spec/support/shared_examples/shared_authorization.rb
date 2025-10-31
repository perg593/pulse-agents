# frozen_string_literal: true

RSpec.shared_examples "shared authorization" do
  # TODO: Require an account!

  # Make the call to the endpoint
  def make_call
    raise NotImplementedError, "You must implement 'make_call' to use 'shared authorization'"
  end

  before do
    sign_out(user)
  end

  context "when the user is not signed in" do
    let(:user) { create(:reporting_only_user, account: account) }

    before do
      make_call
    end

    it "responds appropriately" do
      not_signed_in_assertion
    rescue NameError
      assert_redirected_to sign_in_path
    end
  end

  context "when the user is signed in" do
    before do
      sign_in user

      make_call
    end

    context "when the user is a report-only user" do
      let(:user) { create(:reporting_only_user, account: account) }

      it "responds appropriately" do
        reporting_only_assertion
      rescue NameError
        assert_response 200
      end
    end

    context "when the user is a full access user" do
      let(:user) { create(:user, account: account) }

      it "loads the page" do
        assert_response 200
      end

      context "when the user does not belong to the account" do
        let(:user) { create(:user) }

        it "responds appropriately" do
          full_access_wrong_account_assertion
        rescue NameError
          assert_redirected_to dashboard_path
        end
      end
    end

    context "when the user is an admin" do
      let(:user) { create(:admin, account: account) }

      it "loads the page" do
        assert_response 200
      end

      context "when the user does not belong to the account" do
        let(:user) { create(:admin) }

        it "responds appropriately" do
          admin_wrong_account_assertion
        rescue NameError
          assert_redirected_to dashboard_path
        end
      end
    end
  end
end
