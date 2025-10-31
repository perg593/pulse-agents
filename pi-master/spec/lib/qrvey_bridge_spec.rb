# frozen_string_literal: true
require 'spec_helper'

describe QrveyBridge do
  let(:qrvey_user_id) { "qrvey-user-#{FFaker::Lorem.word}" }
  let(:qrvey_application_id) { "qrvey-application-#{FFaker::Lorem.word}" }

  def build_qrvey_api_item(dashboard_name: "dashboard-#{FFaker::Lorem.word}")
    {
      "pageName" => dashboard_name
    }
  end

  describe "CustomAttributes" do
    let(:owner_id) { 1 }
    let(:viewer_id) { 2 }
    let(:editor_id) { 3 }

    let(:custom_attributes) do
      {
        "version" => "1.0.0",
        "authorization" => {
          owner_id.to_s => { "accessLevel" => QrveyBridge::CustomAttributes::ACCESS_LEVEL_OWNER },
          viewer_id.to_s => { "accessLevel" => QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER },
          editor_id.to_s => { "accessLevel" => QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR }
        }
      }
    end

    before do
      @object = QrveyBridge::CustomAttributes.new(custom_attributes)
    end

    describe "#owner_id" do
      it "returns the owner's ID" do
        expect(@object.owner_id).to eq owner_id
      end
    end

    describe "#=owner_id" do
      context "when the ID belongs to an existing user" do
        let(:new_owner_id) { create(:user).id }

        it "sets the owner's ID" do
          @object.owner_id = new_owner_id

          expect(@object.owner_id).to eq new_owner_id
        end
      end

      context "when an invalid user ID is assigned" do
        [nil, "test", 1].each do |new_owner_id|
          it "raises an error" do
            assert_raises(ArgumentError) { @object.owner_id = new_owner_id }
          end
        end
      end
    end

    describe "#access_level" do
      it "returns the user's access_level" do
        expect(@object.access_level(viewer_id.to_s)).to eq QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER
        expect(@object.access_level(editor_id.to_s)).to eq QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR
      end

      it "returns nil when the user is not found" do
        expect(@object.access_level("non-existent")).to be_nil
      end
    end

    describe "#revoke_access" do
      context "when the user has access" do
        it "removes access_level for the provided user" do
          @object.revoke_access(viewer_id.to_s)

          expect(@object.access_level(viewer_id.to_s)).to be_nil
        end
      end

      context "when the user does not have access" do
        it "removes access_level for the provided user" do
          @object.revoke_access("foo")

          expect(@object.access_level("foo")).to be_nil
        end
      end
    end

    describe "#share_with" do
      context "when the user does not have access to the dashboard" do
        let(:user_id) { "42" }

        it "grants the provided access_level to the provided user" do
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER

          @object.share_with(user_id, user_access_level)

          expect(@object.access_level(user_id)).to eq user_access_level
        end
      end

      context "when the user already has access to the dashboard" do
        let(:user_id) { editor_id }

        before do
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR

          @object.share_with(user_id, user_access_level)
        end

        it "overwrites any of the user's existing access_level" do
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER
          @object.share_with(user_id, user_access_level)

          expect(@object.access_level(user_id)).to eq user_access_level
        end
      end

      context "when an invalid access level is assigned" do
        let(:user_id) { "42" }

        it "raises an error" do
          assert_raises(ArgumentError) do
            @object.share_with(user_id, 3)
          end
        end
      end
    end

    describe "#share_with_many" do
      context "when the user does not have access to the dashboard" do
        it "grants the provided access_level to the provided users" do
          user_id = "42"
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER

          user_id2 = "82"
          user_access_level2 = QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR

          input = {
            user_id => user_access_level,
            user_id2 => user_access_level2
          }

          @object.share_with_many(input)

          expect(@object.access_level(user_id)).to eq user_access_level
          expect(@object.access_level(user_id2)).to eq user_access_level2
        end
      end

      context "when the user already has access to the dashboard" do
        let(:user_id) { editor_id }

        before do
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR

          @object.share_with(user_id, user_access_level)
        end

        it "overwrites any of the user's existing access_level" do
          user_access_level = QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER

          @object.share_with_many({user_id => user_access_level})

          expect(@object.access_level(user_id)).to eq user_access_level
        end
      end
    end

    # TODO: Consider a formal schema
    describe "#to_h" do
      it "returns a hash" do
        result = @object.to_h

        expect(result["customAttributes"]).to eq custom_attributes
      end
    end
  end

  describe "#get_dashboard" do
    let(:qrvey_dashboard_id) { "qrvey-dashboard-#{FFaker::Lorem.word}" }

    it "calls QrveyClient" do
      expect(QrveyClient).to receive(:get_dashboard).with(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)

      described_class.get_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)
    end

    it "returns response wrapped in QrveyDashboardResponse" do
      item = build_qrvey_api_item
      allow(QrveyClient).to receive(:get_dashboard).and_return(item)

      result = described_class.get_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)

      expect(result.dashboard_id).to eq(QrveyDashboardResponse.new(item).dashboard_id)
    end
  end

  describe "#get_all_dashboards" do
    it "calls QrveyClient" do
      allow(QrveyClient).to receive(:get_all_dashboards).with(qrvey_user_id, qrvey_application_id).and_return({"Items" => []}).once

      described_class.get_all_dashboards(qrvey_user_id, qrvey_application_id)
    end

    it "returns response wrapped in QrveyDashboardResponse" do
      item = build_qrvey_api_item
      allow(QrveyClient).to receive(:get_all_dashboards).and_return({"Items" => [item]})

      result = described_class.get_all_dashboards(qrvey_user_id, qrvey_application_id)

      expect(result.count).to eq(1)
      expect(result[0].dashboard_id).to eq(QrveyDashboardResponse.new(item).dashboard_id)
    end
  end

  describe "#clone_dashboard" do
    let(:qrvey_dashboard_id) { "qrvey-dashboard-#{FFaker::Lorem.word}" }
    let(:name_for_clone) { "Clone of #{FFaker::Lorem.word}" }

    it "calls QrveyClient" do
      body = {
        "pageName" => name_for_clone
      }

      allow(QrveyClient).to receive(:clone_dashboard).with(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, body).and_return({"Items" => []}).once

      described_class.clone_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, name_for_clone)
    end

    it "returns response wrapped in QrveyDashboardResponse" do
      item = build_qrvey_api_item(dashboard_name: name_for_clone)
      allow(QrveyClient).to receive(:clone_dashboard).and_return({"Items" => [item]})

      result = described_class.clone_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, name_for_clone)

      expect(result.dashboard_name).to eq(QrveyDashboardResponse.new(item).dashboard_name)
    end
  end

  describe "#create_dashboard" do
    let(:qrvey_dashboard_id) { "qrvey-dashboard-#{FFaker::Lorem.word}" }
    let(:new_dashboard_name) { "New dashboard #{FFaker::Lorem.word}" }
    let(:new_dashboard_description) { "New dashboard #{FFaker::Lorem.phrase}" }

    it "calls QrveyClient" do
      custom_attributes = QrveyBridge::CustomAttributes.new({})

      body = {
        "name" => new_dashboard_name,
        "description" => new_dashboard_description,
        **custom_attributes.to_h
      }
      stubbed_response = {"pageOriginalid" => qrvey_dashboard_id}

      expect(QrveyClient).to receive(:create_dashboard).with(qrvey_user_id, qrvey_application_id, body).and_return(stubbed_response).once

      described_class.create_dashboard(
        qrvey_user_id,
        qrvey_application_id,
        new_dashboard_name,
        new_dashboard_description,
        custom_attributes
      )
    end

    it "returns response wrapped in QrveyDashboardResponse" do
      stubbed_response = {"pageOriginalid" => qrvey_dashboard_id}
      allow(QrveyClient).to receive(:create_dashboard).and_return({"Items" => [stubbed_response]})
      custom_attributes = QrveyBridge::CustomAttributes.new({})

      result = described_class.create_dashboard(
        qrvey_user_id,
        qrvey_application_id,
        new_dashboard_name,
        new_dashboard_description,
        custom_attributes
      )

      expect(result.dashboard_name).to eq(QrveyDashboardResponse.new(stubbed_response).dashboard_name)
    end
  end

  describe "#update_custom_attributes" do
    let(:qrvey_dashboard_id) { "qrvey-dashboard-#{FFaker::Lorem.word}" }

    context "when custom attributes are valid" do
      let(:custom_attributes) do
        c = QrveyBridge::CustomAttributes.new({})
        c.owner_id = create(:user).id
        c
      end

      it "calls QrveyClient" do
        body = custom_attributes.to_h

        expect(QrveyClient).to receive(:patch_dashboard).with(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id, body).once

        described_class.update_custom_attributes(
          qrvey_user_id,
          qrvey_application_id,
          qrvey_dashboard_id,
          custom_attributes
        )
      end

      it "returns response wrapped in QrveyDashboardResponse" do
        stubbed_response = {"pageOriginalid" => qrvey_dashboard_id}
        allow(QrveyClient).to receive(:patch_dashboard).and_return(stubbed_response)

        result = described_class.update_custom_attributes(
          qrvey_user_id,
          qrvey_application_id,
          qrvey_dashboard_id,
          custom_attributes
        )

        expect(result.dashboard_id).to eq(QrveyDashboardResponse.new(stubbed_response).dashboard_id)
      end
    end

    context "when custom attributes are not valid" do
      let(:custom_attributes) { QrveyBridge::CustomAttributes.new({}) }

      it "raises an error" do
        assert_raises(ArgumentError) do
          described_class.update_custom_attributes(
            qrvey_user_id,
            qrvey_application_id,
            qrvey_dashboard_id,
            custom_attributes
          )
        end
      end
    end
  end
end
