# frozen_string_literal: true
require 'spec_helper'
require_relative "schemas/qrvey_sidebar_presenter"
require_relative "../../../lib/qrvey_client/qrvey_client"

describe Control::QrveySidebarPresenter do
  include Rails.application.routes.url_helpers

  let(:account) { create(:account_registered_with_qrvey) }
  let(:survey) { create(:survey, account: account) }
  let(:current_user) { create(:user, account: account) }

  let(:qrvey_user_id) { account.qrvey_user.qrvey_user_id }
  let(:qrvey_application_id) { account.qrvey_user.qrvey_applications.first.qrvey_application_id }

  describe "#using_hardcoded_defaults?" do
    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        @presenter = described_class.new(survey.id, current_user.id)
      end

      it "returns true" do
        expect(@presenter.using_hardcoded_defaults?).to be true
      end
    end

    context "when the account is registered with Qrvey" do
      let(:account) { create(:account_registered_with_qrvey) }

      before do
        allow(QrveyBridge).to receive(:get_all_dashboards).and_return([QrveyDashboardResponse.new({})])
        @presenter = described_class.new(survey.id, current_user.id)
      end

      it "returns false" do
        expect(@presenter.using_hardcoded_defaults?).to be false
      end
    end
  end

  describe "#authorization" do
    let(:dashboard_id) { FFaker::Lorem.unique.word }

    before do
      allow(QrveyClient).to receive(:get_all_dashboards).
        with(qrvey_user_id, qrvey_application_id).
        and_return({ "Items" => api_response_items })

      @presenter = described_class.new(survey.id, current_user.id)
    end

    describe "built-in dashboard" do
      let(:api_response_items) do
        [{
          "name" => FFaker::Lorem.unique.word,
          "pageOriginalid" => dashboard_id
        }]
      end

      it "has a valid schema" do
        authorization = @presenter.authorization

        expect(authorization.keys).to contain_exactly(dashboard_id)

        authorization.each_value do |permission|
          assert_valid_schema Schemas::QrveySidebarPresenter::AuthorizationSchema, permission
        end
      end

      it "returns a list of permissions for every dashboard" do
        authorization = @presenter.authorization

        expected_options = {
          canDelete: false,
          canShare: false,
          canCopy: true,
          canEdit: false
        }

        expect(authorization[dashboard_id]).to match_array expected_options
      end
    end

    describe "my dashboard" do
      let(:api_response_items) do
        custom_attributes = QrveyBridge::CustomAttributes.new
        custom_attributes.owner_id = current_user.id

        [{
          "name" => FFaker::Lorem.unique.word,
          "pageOriginalid" => dashboard_id,
          **custom_attributes.to_h
        }]
      end

      it "has a valid schema" do
        authorization = @presenter.authorization

        expect(authorization.keys).to contain_exactly(dashboard_id)

        authorization.each_value do |permission|
          assert_valid_schema Schemas::QrveySidebarPresenter::AuthorizationSchema, permission
        end
      end

      it "returns a list of permissions for every dashboard" do
        authorization = @presenter.authorization

        expected_options = {
          canDelete: true,
          canShare: true,
          canCopy: true,
          canEdit: true
        }

        expect(authorization[dashboard_id]).to match_array expected_options
      end
    end

    describe "dashboard shared with me" do
      let(:api_response_items) do
        custom_attributes = QrveyBridge::CustomAttributes.new
        custom_attributes.owner_id = create(:user).id
        custom_attributes.share_with(current_user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

        [{
          "name" => FFaker::Lorem.unique.word,
          "pageOriginalid" => dashboard_id,
          **custom_attributes.to_h
        }]
      end

      it "has a valid schema" do
        authorization = @presenter.authorization

        expect(authorization.keys).to contain_exactly(dashboard_id)

        authorization.each_value do |permission|
          assert_valid_schema Schemas::QrveySidebarPresenter::AuthorizationSchema, permission
        end
      end

      it "returns a list of permissions for every dashboard" do
        authorization = @presenter.authorization

        expected_options = {
          canDelete: false,
          canShare: true,
          canCopy: true,
          canEdit: false
        }

        expect(authorization[dashboard_id]).to match_array expected_options
      end
    end
  end

  describe "#share_options" do
    let(:api_response_items) do
      items = []

      custom_attributes = QrveyBridge::CustomAttributes.new
      custom_attributes.owner_id = create(:user).id
      custom_attributes.share_with(current_user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

      items << {
        "name" => FFaker::Lorem.unique.word,
        "pageOriginalid" => FFaker::Lorem.unique.word,
        **custom_attributes.to_h
      }

      custom_attributes = QrveyBridge::CustomAttributes.new

      items << {
        "name" => FFaker::Lorem.unique.word,
        "pageOriginalid" => FFaker::Lorem.unique.word,
        **custom_attributes.to_h
      }

      items
    end

    context "when the account is registered with Qrvey" do
      before do
        3.times { create(:user, account: account) }

        allow(QrveyClient).to receive(:get_all_dashboards).
          with(qrvey_user_id, qrvey_application_id).
          and_return({ "Items" => api_response_items })

        @presenter = described_class.new(survey.id, current_user.id)
      end

      it "has a valid schema" do
        options = @presenter.share_options

        dashboard_ids = api_response_items.map do |item|
          qrvey_dashboard_response = QrveyDashboardResponse.new(item)
          qrvey_dashboard_response.dashboard_id
        end

        expect(options[:options].keys).to match_array dashboard_ids

        options[:options].each_value do |dashboard_options|
          dashboard_options.each do |user_option|
            assert_valid_schema Schemas::QrveySidebarPresenter::ShareOptionSchema, user_option
          end
        end
      end

      it "returns a list of users for every dashboard" do
        options = @presenter.share_options

        # The current user is always excluded
        users = account.users.where.not(id: current_user.id)

        api_response_items.each do |item|
          qrvey_dashboard_response = QrveyDashboardResponse.new(item)
          qrvey_dashboard_id = qrvey_dashboard_response.dashboard_id

          expected_options = users.map do |user|
            shared_with_user = qrvey_dashboard_response.dashboard_shared_with_user?(user.id)

            {
              userId: user.id,
              userName: user.first_name,
              shared: shared_with_user,
              permissions: nil
            }
          end

          expect(options[:options][qrvey_dashboard_id]).to match_array expected_options
        end
      end
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        @presenter = described_class.new(survey.id, current_user.id)
      end

      it "returns an empty object" do
        options = @presenter.share_options

        expect(options[:options]).to eq({})
      end
    end
  end

  describe "#links" do
    let(:default_dashboard_links) do
      {
        builtIn: [
          {
            text: "Overview",
            url: report_survey_path(survey.id),
            current: true,
            dashboardId: nil
          },
          {
            text: "Trends",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][0][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][0][:id]
          },
          {
            text: "Device",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][1][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][1][:id]
          },
          {
            text: "URLs",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][2][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][2][:id]
          },
          {
            text: "Media",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][3][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][3][:id]
          },
          {
            text: "Visit Frequency",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][4][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][4][:id]
          },
          {
            text: "Raw Data",
            url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: QRVEY_CONFIG[:client_reports][:dashboards][5][:id]),
            current: false,
            additionalClasses: "sublist-item",
            dashboardId: QRVEY_CONFIG[:client_reports][:dashboards][5][:id]
          }
        ]
      }
    end

    context "when the account is not registered with Qrvey" do
      let(:account) { create(:account) }

      before do
        @presenter = described_class.new(survey.id, current_user.id)
      end

      it "has a valid schema" do
        links = @presenter.links

        assert_valid_schema Schemas::QrveySidebarPresenter::LinksSchema, links
      end

      it "returns default dashboard links" do
        expect(@presenter.links[:builtIn]).to match_array default_dashboard_links[:builtIn]
      end
    end

    context "when the account is registered with Qrvey" do
      let(:built_in_dashboard_items) do
        QrveyDashboardMapping.all.map do |qrvey_dashboard_mapping|
          {
            "name" => qrvey_dashboard_mapping.qrvey_name,
            "pageOriginalid" => FFaker::Lorem.unique.word
          }
        end
      end

      let(:api_response_items) do
        built_in_dashboard_items
      end

      def api_dashboard_id_for_dashboard(dashboard)
        api_response_item = api_response_items.detect do |item|
          qrvey_dashboard_response = QrveyDashboardResponse.new(item)
          qrvey_dashboard_response.dashboard_name == dashboard.qrvey_name
        end

        QrveyDashboardResponse.new(api_response_item).dashboard_id
      end

      before do
        6.times { |i| create(:qrvey_dashboard_mapping, position: i + 1) }

        allow(QrveyClient).to receive(:get_all_dashboards).
          with(qrvey_user_id, qrvey_application_id).
          and_return({ "Items" => api_response_items })
      end

      # This is typically the case when the qrvey application has not received
      # a "content deployment".
      context "when no default dashboards are found via API" do
        let(:api_response_items) { [] }

        before do
          @presenter = described_class.new(survey.id, current_user.id)
        end

        it "returns default dashboard links" do
          expect(@presenter.links[:builtIn]).to match_array default_dashboard_links[:builtIn]
        end

        it "does not report to Rollbar" do
          expect(Rollbar).not_to receive(:warning)

          @presenter.links
        end
      end

      context "when a default dashboard is not found via API" do
        before do
          @dashboard_name_to_exclude = QrveyDashboardMapping.all.order("RANDOM()").pick(:qrvey_name)
          api_response_items.delete_if { |item| item["name"] == @dashboard_name_to_exclude }

          @presenter = described_class.new(survey.id, current_user.id)
        end

        it "reports to Rollbar" do
          expect(Rollbar).to receive(:warning).once

          @presenter.links
        end

        it "doesn't return the missing dashboard" do
          links = @presenter.links[:builtIn]

          expect(links.count).to eq QrveyDashboardMapping.count
          expect(links.detect { |link| link[:name] == @dashboard_name_to_exclude }).to be_nil
        end
      end

      context "when survey_id is not provided" do
        before do
          @presenter = described_class.new(nil, current_user.id)
        end

        it "excludes survey_id from URLs" do
          @presenter.links.values.flatten.each do |link|
            expect(link[:url]).not_to include("survey_id")
          end
        end
      end

      context "when all default dashboards are found via API" do
        before do
          @presenter = described_class.new(survey.id, current_user.id)
        end

        it "has a valid schema" do
          links = @presenter.links

          assert_valid_schema Schemas::QrveySidebarPresenter::LinksSchema, links
        end

        context "when the user has reports on Qrvey" do
          let(:custom_dashboard_id_a) { "custom-dashboard-id-#{FFaker::Lorem.unique.word}" }
          let(:custom_dashboard_id_z) { "custom-dashboard-id-#{FFaker::Lorem.unique.word}" }
          let(:custom_dashboard_name_a) { "a-custom-dashboard-#{FFaker::Lorem.unique.word}" }
          let(:custom_dashboard_name_z) { "z-custom-dashboard-#{FFaker::Lorem.unique.word}" }

          let(:api_response_items) do
            custom_attributes = QrveyBridge::CustomAttributes.new
            custom_attributes.owner_id = current_user.id

            [
              *built_in_dashboard_items,
              {
                "name" => custom_dashboard_name_z,
                "pageOriginalid" => custom_dashboard_id_z,
                **custom_attributes.to_h
              },
              {
                "name" => custom_dashboard_name_a,
                "pageOriginalid" => custom_dashboard_id_a,
                **custom_attributes.to_h
              }
            ]
          end

          it "has the expected 'my reports' dashboard values" do
            links = @presenter.links[:myReports]

            expected_links = [
              {
                text: custom_dashboard_name_a,
                url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: custom_dashboard_id_a),
                editModeUrl: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: custom_dashboard_id_a, mode: "edit"),
                current: false,
                additionalClasses: "sublist-item",
                dashboardId: custom_dashboard_id_a
              },
              {
                text: custom_dashboard_name_z,
                url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: custom_dashboard_id_z),
                editModeUrl: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: custom_dashboard_id_z, mode: "edit"),
                current: false,
                additionalClasses: "sublist-item",
                dashboardId: custom_dashboard_id_z
              }
            ]

            expect(links).to eq expected_links
          end
        end

        context "when another user has shared a report with current user" do
          let(:shared_custom_dashboard_id_a) { "shared-custom-dashboard-id-#{FFaker::Lorem.unique.word}" }
          let(:shared_custom_dashboard_id_z) { "shared-custom-dashboard-id-#{FFaker::Lorem.unique.word}" }
          let(:shared_custom_dashboard_name_a) { "a-shared-custom-dashboard-#{FFaker::Lorem.unique.word}" }
          let(:shared_custom_dashboard_name_z) { "z-shared-custom-dashboard-#{FFaker::Lorem.unique.word}" }

          let(:api_response_items) do
            shared_custom_attributes = QrveyBridge::CustomAttributes.new
            shared_custom_attributes.owner_id = create(:user).id
            shared_custom_attributes.share_with(current_user.id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

            [
              {
                "name" => shared_custom_dashboard_name_a,
                "pageOriginalid" => shared_custom_dashboard_id_a,
                **shared_custom_attributes.to_h
              },
              {
                "name" => shared_custom_dashboard_name_z,
                "pageOriginalid" => shared_custom_dashboard_id_z,
                **shared_custom_attributes.to_h
              }
            ]
          end

          it "has the expected 'shared with me' dashboard values" do
            links = @presenter.links[:sharedWithMe]

            expected_links = [
              {
                text: shared_custom_dashboard_name_a,
                url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: shared_custom_dashboard_id_a),
                current: false,
                additionalClasses: "sublist-item",
                dashboardId: shared_custom_dashboard_id_a
              },
              {
                text: shared_custom_dashboard_name_z,
                url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: shared_custom_dashboard_id_z),
                current: false,
                additionalClasses: "sublist-item",
                dashboardId: shared_custom_dashboard_id_z
              }
            ]

            expect(links).to eq expected_links
          end
        end

        it "has the expected built-in dashboard values" do
          links = @presenter.links[:builtIn]

          expect(links.count).to eq QrveyDashboardMapping.all.count + 1

          expect(links[0]).to eq(
            {
              text: "Overview",
              url: report_survey_path(survey.id),
              current: true,
              dashboardId: nil
            }
          )

          links.shift

          dashboard_mappings = QrveyDashboardMapping.all.order(:position)

          links.each_with_index do |link, i|
            dashboard_mapping = dashboard_mappings[i]
            dashboard_id = api_dashboard_id_for_dashboard(dashboard_mapping)

            expect(link).to eq(
              {
                text: dashboard_mapping.pi_name,
                url: client_reports_qrvey_path(survey_id: survey.id, dashboard_id: dashboard_id),
                current: false,
                additionalClasses: "sublist-item",
                dashboardId: dashboard_id
              }
            )
          end
        end

        describe "current_dashboard_id" do
          context "when not provided" do
            it "current is true for first dashboard" do
              @presenter = described_class.new(survey.id, current_user.id)

              links = @presenter.links[:builtIn]

              expect(links[0][:current]).to be(true)
              expect(links[1..].map { |link| link[:current] }.uniq).to contain_exactly(false)
            end
          end

          context "when provided" do
            before do
              @current_dashboard_mapping = QrveyDashboardMapping.all.order(:position)[4]

              @presenter = described_class.new(survey.id, current_user.id, api_dashboard_id_for_dashboard(@current_dashboard_mapping))
            end

            it "current is true for dashboard with matching ID" do
              links = @presenter.links.values.flatten

              current_dashboard_link = links.detect { |link| link[:text] == @current_dashboard_mapping.pi_name }
              expect(current_dashboard_link[:current]).to be(true)

              links.delete(current_dashboard_link)
              expect(links.map { |link| link[:current] }.uniq).to contain_exactly(false)
            end
          end
        end
      end
    end
  end
end
