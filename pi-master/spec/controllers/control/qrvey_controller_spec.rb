# frozen_string_literal: true
require 'spec_helper'

describe Control::QrveyController do
  describe "PUT #change_dashboard_permissions" do
    let(:user) { create(:user, account: account) }

    # TODO: Test authorization
    # TODO: Validate parameters
    before do
      sign_in user
      request.env["HTTP_REFERER"] = client_reports_qrvey_path
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }
      let(:user_id_to_change_a) { create(:user, account: account).id }
      let(:user_id_to_change_b) { create(:user, account: account).id }

      let(:qrvey_user) { account.qrvey_user }
      let(:qrvey_application_id) { qrvey_user.qrvey_applications.first.qrvey_application_id }
      let(:qrvey_dashboard_id) { FFaker::Lorem.word }

      let(:existing_custom_attributes) do
        custom_attributes = QrveyBridge::CustomAttributes.new
        custom_attributes.owner_id = user.id
        custom_attributes.share_with(user_id_to_change_a, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)
        custom_attributes.share_with(user_id_to_change_b, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)

        custom_attributes
      end

      def assert_calls_api_with_custom_attributes(params, expected_custom_attributes)
        expect(QrveyBridge).to receive(:update_custom_attributes).with(
          qrvey_user.qrvey_user_id,
          qrvey_application_id,
          qrvey_dashboard_id,
          expected_custom_attributes
        ).once

        put :change_dashboard_permissions, params: params

        assert_redirected_to client_reports_qrvey_path
      end

      context "when changing permissions" do
        before do
          # Existing custom attributes are stored on Qrvey, which
          # we retrieve via API
          allow(QrveyBridge).to receive(:get_dashboard).with(
            qrvey_user.qrvey_user_id,
            qrvey_application_id,
            qrvey_dashboard_id
          ).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h))
        end

        context "when changing one user's access level" do
          let(:user_params) { [{id: user_id_to_change_a, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR}] }
          let(:params) { { qrvey_dashboard_id: qrvey_dashboard_id, users: user_params } }

          it "calls Qrvey with the expected custom attributes" do
            expected_custom_attributes = existing_custom_attributes.dup
            expected_custom_attributes.share_with(user_id_to_change_a, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)

            assert_calls_api_with_custom_attributes(params, expected_custom_attributes)
          end
        end

        context "when revoking one user's access" do
          let(:user_params) { [{id: user_id_to_change_a, permissions: ""}] }
          let(:params) { { qrvey_dashboard_id: qrvey_dashboard_id, users: user_params } }

          it "calls Qrvey with the expected custom attributes" do
            expected_custom_attributes = existing_custom_attributes.dup
            expected_custom_attributes.revoke_access(user_id_to_change_a)

            assert_calls_api_with_custom_attributes(params, expected_custom_attributes)
          end
        end

        context "when changing multiple users' access level" do
          let(:user_params) do
            [
              {id: user_id_to_change_a, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR},
              {id: user_id_to_change_b, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER}
            ]
          end
          let(:params) { { qrvey_dashboard_id: qrvey_dashboard_id, users: user_params } }

          it "calls Qrvey with the expected custom attributes" do
            expected_custom_attributes = existing_custom_attributes.dup
            expected_custom_attributes.share_with(user_id_to_change_a, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)
            expected_custom_attributes.share_with(user_id_to_change_b, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

            assert_calls_api_with_custom_attributes(params, expected_custom_attributes)
          end
        end
      end

      context "when revoking access when you are not the owner" do
        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user, account: account).id
          custom_attributes.share_with(user_id_to_change_a, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

          custom_attributes.to_h
        end

        let(:users) { [{id: user_id_to_change_a, permissions: ""}] }
        let(:params) { { qrvey_dashboard_id: qrvey_dashboard_id, users: user_params } }

        it "does not allow it" do
          QrveyBridge.stub(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h))

          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          put :change_dashboard_permissions, params: { qrvey_dashboard_id: qrvey_dashboard_id, users: users }

          assert_redirected_to client_reports_qrvey_path
        end
      end

      context "when lowering someone with more permissions that you" do
        let(:user_id_to_decrease) { create(:user, account: account).id }
        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user, account: account).id
          custom_attributes.share_with(user_id_to_decrease, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)
          custom_attributes.share_with(user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

          custom_attributes.to_h
        end

        let(:users) { [{id: user_id_to_decrease.to_s, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER}] }

        it "does not allow it" do
          QrveyBridge.stub(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h))

          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          put :change_dashboard_permissions, params: { qrvey_dashboard_id: qrvey_dashboard_id, users: users }

          assert_redirected_to client_reports_qrvey_path
        end
      end

      context "when increasing someone's permissions above your own" do
        let(:user_id_to_increase) { create(:user, account: account).id }
        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user, account: account).id
          custom_attributes.share_with(user_id_to_increase, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)
          custom_attributes.share_with(user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

          custom_attributes.to_h
        end

        let(:users) { [{id: user_id_to_increase.to_s, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR}] }

        it "does not allow it" do
          # Confirm that we retrieved any existing customAttributes via API
          expect(QrveyBridge).to receive(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h)).once

          # Confirm that we DO NOT update the dashboard
          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          put :change_dashboard_permissions, params: { qrvey_dashboard_id: qrvey_dashboard_id, users: users }

          assert_redirected_to client_reports_qrvey_path
        end
      end

      context "when supplying a user ID from another account" do
        let(:user_id_to_increase) { create(:user, account: create(:account)).id }
        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = user.id

          custom_attributes.to_h
        end

        let(:users) { [{id: user_id_to_increase.to_s, permissions: QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER}] }

        it "does not allow it" do
          # Confirm that we retrieved any existing customAttributes via API
          QrveyBridge.stub(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h))

          # Confirm that we DO NOT update the dashboard
          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          put :change_dashboard_permissions, params: { qrvey_dashboard_id: qrvey_dashboard_id, users: users }

          assert_redirected_to client_reports_qrvey_path
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        allow(account).to receive(:registered_with_qrvey?).and_return(false)
      end

      it "redirects" do
        put :change_dashboard_permissions, params: {}

        assert_redirected_to dashboard_path
      end
    end
  end

  # TODO: Test authorization
  # TODO: Validate parameters
  describe "PUT #share_dashboard" do
    let(:access_level) { QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR }
    let(:permissions_params) { QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR }
    let(:user) { create(:user, account: account) }
    let(:owner_id) { create(:user, account: account).id }

    before do
      sign_in user
      request.env["HTTP_REFERER"] = client_reports_qrvey_path
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }
      let(:owner_id) { user.id }
      let(:existing_custom_attributes) do
        custom_attributes = QrveyBridge::CustomAttributes.new
        custom_attributes.owner_id = owner_id

        custom_attributes.to_h
      end
      let(:qrvey_user) { account.qrvey_user }
      let(:qrvey_application_id) { qrvey_user.qrvey_applications.first.qrvey_application_id }
      let(:qrvey_dashboard_id) { FFaker::Lorem.word }

      context "when making a valid set of changes" do
        let(:user_ids_to_share_with) { [create(:user, account: account).id] * 3 }

        let(:new_custom_attributes) do
          c = QrveyBridge::CustomAttributes.new
          c.owner_id = owner_id

          shared_with = {}
          user_ids_to_share_with.each do |user_id|
            shared_with[user_id.to_s] = access_level
          end

          c.share_with_many(shared_with)

          c
        end

        it "makes a request to Qrvey to get the dashboard then to update its share permissions" do
          # Confirm that we retrieved any existing customAttributes via API
          expect(QrveyBridge).to receive(:get_dashboard).with(
            qrvey_user.qrvey_user_id,
            qrvey_application_id,
            qrvey_dashboard_id
          ).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h)).once

          # Confirm that we updated the dashboard
          expect(QrveyBridge).to receive(:update_custom_attributes).with(
            qrvey_user.qrvey_user_id,
            qrvey_application_id,
            qrvey_dashboard_id,
            new_custom_attributes
          ).once

          params = {
            qrvey_dashboard_id: qrvey_dashboard_id,
            user_ids_to_share_with: user_ids_to_share_with,
            permissions: permissions_params
          }

          put :share_dashboard, params: params
        end
      end

      context "when supplying a user ID from another account" do
        let(:user_id_to_increase) { create(:user, account: create(:account)).id }
        let(:user_ids_to_share_with) { [user_id_to_increase] }
        let(:permissions_params) { QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER }
        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = user.id

          custom_attributes.to_h
        end

        it "does not allow it" do
          # Confirm that we retrieved any existing customAttributes via API
          QrveyBridge.stub(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h))

          # Confirm that we DO NOT update the dashboard
          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          params = {
            qrvey_dashboard_id: qrvey_dashboard_id,
            user_ids_to_share_with: user_ids_to_share_with,
            permissions: permissions_params
          }

          put :share_dashboard, params: params

          assert_redirected_to client_reports_qrvey_path
        end
      end

      context "when lowering someone with more permissions that you" do
        let(:user_id_to_decrease) { create(:user, account: account).id }
        let(:user_ids_to_share_with) { [user_id_to_decrease, create(:user).id] }
        let(:permissions_params) { QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER }

        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user, account: account).id
          custom_attributes.share_with(user_id_to_decrease, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)
          custom_attributes.share_with(user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

          custom_attributes.to_h
        end

        it "does not allow it" do
          # Confirm that we retrieved any existing customAttributes via API
          expect(QrveyBridge).to receive(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h)).once

          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          params = {
            qrvey_dashboard_id: qrvey_dashboard_id,
            user_ids_to_share_with: user_ids_to_share_with,
            permissions: permissions_params
          }

          put :share_dashboard, params: params

          assert_redirected_to client_reports_qrvey_path
        end
      end

      context "when increasing someone's permissions above your own" do
        let(:user_id_to_increase) { create(:user, account: account).id }
        let(:user_ids_to_share_with) { [user_id_to_increase, create(:user, account: account).id] }
        let(:permissions_params) { QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR }

        let(:existing_custom_attributes) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user, account: account).id
          custom_attributes.share_with(user_id_to_increase, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)
          custom_attributes.share_with(user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

          custom_attributes.to_h
        end

        it "does not allow it" do
          # Confirm that we retrieved any existing customAttributes via API
          expect(QrveyBridge).to receive(:get_dashboard).and_return(QrveyDashboardResponse.new(existing_custom_attributes.to_h)).once

          # Confirm that we DO NOT update the dashboard
          expect(QrveyBridge).not_to receive(:update_custom_attributes)

          params = {
            qrvey_dashboard_id: qrvey_dashboard_id,
            user_ids_to_share_with: user_ids_to_share_with,
            permissions: permissions_params
          }

          put :share_dashboard, params: params

          assert_redirected_to client_reports_qrvey_path
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        allow(account).to receive(:registered_with_qrvey?).and_return(false)
      end

      it "redirects" do
        put :share_dashboard, params: {}

        assert_redirected_to dashboard_path
      end
    end
  end

  describe "POST #clone_dashboard" do
    let(:user) { create(:user, account: account) }
    let(:survey_id) { 42 }

    # TODO: Find a way to test this
    # it_behaves_like "shared authorization" do
    #   let(:account) { create(:account_registered_with_qrvey) }
    #
    #   def make_call
    #     allow(QrveyClient).to receive(:clone_dashboard)
    #
    #     post :clone_dashboard, params: { dashboard_id: FFaker::Lorem.word }
    #   end
    # end

    before do
      sign_in user
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }
      let(:qrvey_dashboard_id) { "dashboard_id_#{FFaker::Lorem.word}" }
      let(:qrvey_dashboard_name) { "dashboard_name_#{FFaker::Lorem.word}" }
      let(:cloned_dashboard_id) { "cloned-id-#{FFaker::Lorem.word}" }

      let(:qrvey_response) { QrveyDashboardResponse.new({"pageid" => cloned_dashboard_id}) }

      it "makes a request to Qrvey to clone the dashboard" do
        qrvey_user = account.qrvey_user
        qrvey_user_id = qrvey_user.qrvey_user_id
        qrvey_application_id = qrvey_user.qrvey_applications.first.qrvey_application_id

        # it "uses the name provided" do
        expect(QrveyBridge).to receive(:clone_dashboard).
          with(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, qrvey_dashboard_name).
          and_return(qrvey_response).once

        expected_custom_attributes = QrveyBridge::CustomAttributes.new
        expected_custom_attributes.owner_id = user.id

        # it "assigns the current user as owner" do
        # it "does not copy over access permissions" do
        expect(QrveyBridge).to receive(:update_custom_attributes).with(
          qrvey_user_id,
          qrvey_application_id,
          cloned_dashboard_id,
          expected_custom_attributes
        ).once

        post :clone_dashboard, params: { qrvey_dashboard_id: qrvey_dashboard_id, qrvey_dashboard_name: qrvey_dashboard_name }
      end

      context "when a survey_id is included" do
        it "redirects to the new dashboard in edit mode" do
          allow(QrveyBridge).to receive(:clone_dashboard).and_return(qrvey_response)
          allow(QrveyBridge).to receive(:update_custom_attributes)

          post :clone_dashboard, params: { qrvey_dashboard_id: qrvey_dashboard_id, qrvey_dashboard_name: qrvey_dashboard_name, survey_id: survey_id }

          assert_redirected_to client_reports_qrvey_path(survey_id: survey_id, dashboard_id: cloned_dashboard_id, mode: "edit")
        end
      end

      context "when a survey_id is not included" do
        it "redirects to the new dashboard in edit mode" do
          allow(QrveyBridge).to receive(:clone_dashboard).and_return(qrvey_response)
          allow(QrveyBridge).to receive(:update_custom_attributes)

          post :clone_dashboard, params: { qrvey_dashboard_id: qrvey_dashboard_id, qrvey_dashboard_name: qrvey_dashboard_name }

          assert_redirected_to client_reports_qrvey_path(dashboard_id: cloned_dashboard_id, mode: "edit")
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        allow(account).to receive(:registered_with_qrvey?).and_return(false)
      end

      it "redirects" do
        post :clone_dashboard, params: { qrvey_dashboard_id: FFaker::Lorem.word, qrvey_dashboard_name: FFaker::Lorem.word }

        assert_redirected_to dashboard_path
      end
    end
  end

  describe "POST #create_dashboard" do
    let(:user) { create(:user, account: account) }
    let(:survey_id) { 42 }
    let(:dashboard_name) { FFaker::Lorem.word }
    let(:dashboard_description) { FFaker::Lorem.sentence }

    let(:required_params) { { dashboard_name: dashboard_name, dashboard_description: dashboard_description } }

    # it_behaves_like "shared authorization" do
    #   let(:account) { create(:account_registered_with_qrvey) }
    #
    #   def make_call
    #     stubbed_response = {"pageOriginalid" => qrvey_dashboard_id}
    #     allow(QrveyClient).to receive(:create_dashboard).and_return(stubbed_response)
    #
    #     post :create_dashboard, params: required_params
    #   end
    # end

    before do
      sign_in user
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }
      let(:qrvey_user) { account.qrvey_user }
      let(:custom_attributes) do
        c = QrveyBridge::CustomAttributes.new({})
        c.owner_id = account.users.first.id
        c
      end
      let(:new_qrvey_dashboard_id) { "New-Qrvey-Dashboard-#{FFaker::Lorem.word}" }
      let(:qrvey_response) { QrveyDashboardResponse.new({"pageid" => new_qrvey_dashboard_id}) }

      before do
        allow(QrveyBridge).to receive(:create_dashboard).and_return(qrvey_response)
      end

      it "makes a request to Qrvey to create the dashboard" do
        expect(QrveyBridge).to receive(:create_dashboard).with(
          qrvey_user.qrvey_user_id,
          qrvey_user.qrvey_applications.first.qrvey_application_id,
          dashboard_name,
          dashboard_description,
          custom_attributes
        ).once

        post :create_dashboard, params: required_params
      end

      describe "redirection" do
        context "when survey_id is included" do
          let(:params) { required_params.merge(survey_id: survey_id) }

          it "redirects to new dashboard page" do
            post :create_dashboard, params: params

            assert_redirected_to client_reports_qrvey_path(survey_id: survey_id, dashboard_id: new_qrvey_dashboard_id, mode: "edit")
          end
        end

        context "when survey_id is not included" do
          it "redirects to new dashboard page" do
            post :create_dashboard, params: required_params

            assert_redirected_to client_reports_qrvey_path(dashboard_id: new_qrvey_dashboard_id, mode: "edit")
          end
        end
      end

      describe "parameter validation" do
        # TODO: Find better way
        [:dashboard_name, :dashboard_description].each do |param_to_omit|
          it "redirects to the survey dashboard" do
            params = required_params
            params.delete(param_to_omit)

            post :create_dashboard, params: params

            assert_redirected_to dashboard_path
          end
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        allow(account).to receive(:registered_with_qrvey?).and_return(false)
      end

      it "redirects" do
        post :create_dashboard, params: required_params

        assert_redirected_to dashboard_path
      end
    end
  end

  describe "DELETE #delete_dashboard" do
    let(:user) { create(:user, account: account) }

    # it_behaves_like "shared authorization" do
    #   let(:account) { create(:account_registered_with_qrvey) }
    #
    #   def make_call
    #     allow(QrveyClient).to receive(:delete_dashboard)
    #
    #     delete :delete_dashboard, params: { dashboard_id: FFaker::Lorem.word }
    #   end
    # end

    before do
      sign_in user
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }
      let(:qrvey_dashboard_id) { FFaker::Lorem.word }
      let(:qrvey_user) { account.qrvey_user }

      context "when the user is the owner of the dashboard" do
        before do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = user.id

          stubbed_qrvey_response = QrveyDashboardResponse.new(custom_attributes.to_h)

          QrveyBridge.stub(:get_dashboard).and_return(stubbed_qrvey_response)
        end

        it "makes a request to Qrvey to destroy the dashboard" do
          expect(QrveyClient).to receive(:delete_dashboard).with(
            qrvey_user.qrvey_user_id,
            qrvey_user.qrvey_applications.first.qrvey_application_id,
            qrvey_dashboard_id
          ).once

          delete :delete_dashboard, params: { qrvey_dashboard_id: qrvey_dashboard_id }

          assert_response :ok
        end
      end

      context "when the user is not the owner of the dashboard" do
        before do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = create(:user).id

          stubbed_qrvey_response = QrveyDashboardResponse.new(custom_attributes.to_h)

          QrveyBridge.stub(:get_dashboard).and_return(stubbed_qrvey_response)
        end

        it "does not make a request to Qrvey to destroy the dashboard" do
          expect(QrveyClient).not_to receive(:delete_dashboard)

          delete :delete_dashboard, params: { qrvey_dashboard_id: qrvey_dashboard_id }

          assert_response :forbidden
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        allow(account).to receive(:registered_with_qrvey?).and_return(false)
      end

      it "redirects" do
        delete :delete_dashboard, params: { dashboard_id: FFaker::Lorem.word }

        assert_redirected_to dashboard_path
      end
    end
  end

  describe "GET #platform_health" do
    let(:stubbed_body) do
      {
        appid: "nFvQyYFE2",
        userid: "FU8fv5Yz0",
        permissions: [
          {
            dataset_id: "*",
            record_permissions: [
              {
                security_name: "account_id",
                values: ['*']
              }
            ]
          }
        ]
      }
    end

    before do
      sign_in user

      allow(QrveyClient).to receive(:generate_token).and_return("placeholder_token")

      get :platform_health
    end

    context "when the user is not an admin" do
      let(:user) { create(:user) }

      it { is_expected.to respond_with(302) }
      it { is_expected.to redirect_to(dashboard_url) }

      it "does not call Qrvey" do
        expect(QrveyClient).not_to receive(:generate_token)
      end
    end

    context "when the user is an admin" do
      let(:user) { create(:admin) }

      it { is_expected.to respond_with(200) }
      it { is_expected.to render_template("platform_health") }

      it "calls Qrvey" do
        # rubocop:disable RSpec/MessageSpies
        expect(QrveyClient).to have_received(:generate_token).with(stubbed_body)
      end
    end
  end

  describe "GET #dashboard_builder" do
    let(:stubbed_body) do
      {
        appid: "-d04u5atA",
        asset_permissions: {
          datasets: {
            dataset_ids: ["ywqweemyl"]
          }
        },
        dashboard_id: "2ILZUY1UBXUvxb5XrLsOP",
        userid: "XoYxNFoyo"
      }
    end

    before do
      user = create(:reporting_only_user, account: account)
      sign_in user

      allow(QrveyClient).to receive(:generate_token).and_return("placeholder_token")

      get :dashboard_builder
    end

    context "when the account does not belong to IKEA" do
      let(:account) { create(:account) }

      it { is_expected.to respond_with(302) }
      it { is_expected.to redirect_to(dashboard_url) }

      it "does not call Qrvey" do
        expect(QrveyClient).not_to receive(:generate_token)
      end
    end

    context "when the account belongs to IKEA" do
      let(:account) { create(:account, id: 341) }

      it { is_expected.to respond_with(200) }
      it { is_expected.to render_template("dashboard_builder") }

      it "calls Qrvey" do
        expect(QrveyClient).to have_received(:generate_token).with(stubbed_body)
      end
    end
  end
end
