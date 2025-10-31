# frozen_string_literal: true
require 'spec_helper'

describe QrveyDashboardResponse do
  describe "#custom_attributes" do
    subject { described_class.new(qrvey_dashboard_item).custom_attributes }

    context "when a customAttributes hash is provided" do
      let(:qrvey_dashboard_item) { QrveyBridge::CustomAttributes.new.to_h }

      it { is_expected.to eq QrveyBridge::CustomAttributes.new(qrvey_dashboard_item["customAttributes"]) }
    end

    context "when a customAttributes hash is not provided" do
      let(:qrvey_dashboard_item) { {} }

      it { is_expected.to eq QrveyBridge::CustomAttributes.new({}) }
    end
  end

  describe "#built_in_dashboard?" do
    subject { qrvey_dashboard_response.built_in_dashboard? }

    let(:qrvey_dashboard_item) do
      { "name" => qrvey_dashboard_name }
    end
    let(:qrvey_dashboard_response) { described_class.new(qrvey_dashboard_item) }

    before do
      @qrvey_dashboard_mapping_name = create(:qrvey_dashboard_mapping).qrvey_name
    end

    context "when the dashboard name is found in QrveyDashboardMapping" do
      let(:qrvey_dashboard_name) { @qrvey_dashboard_mapping_name }

      it { is_expected.to be true }
    end

    context "when the dashboard name is not found in QrveyDashboardMapping" do
      let(:qrvey_dashboard_name) { "dashboard-#{FFaker::Lorem.word}" }

      it { is_expected.to be false }
    end
  end

  describe "#dashboard_owned_by_user?" do
    subject { qrvey_dashboard_response.dashboard_owned_by_user?(user_id) }

    let(:owner_id) { create(:user).id }
    let(:qrvey_dashboard_response) { described_class.new(qrvey_dashboard_item) }
    let(:qrvey_dashboard_item) do
      custom_attributes = QrveyBridge::CustomAttributes.new
      custom_attributes.owner_id = owner_id

      custom_attributes.to_h
    end

    context "when the user_id is the same as the owner's" do
      let(:user_id) { owner_id }

      it { is_expected.to be true }
    end

    context "when the user_id is not the same as the owner's" do
      let(:user_id) { owner_id + 1 }

      it { is_expected.to be false }
    end
  end

  describe "#dashboard_name" do
    let(:dashboard_name) { FFaker::Lorem.word }
    let(:qrvey_dashboard_item) { {"name" => dashboard_name} }

    it "returns the dashboard's name" do
      qrvey_dashboard_response = described_class.new(qrvey_dashboard_item)

      expect(qrvey_dashboard_response.dashboard_name).to eq dashboard_name
    end
  end

  describe "#dashboard_id" do
    let(:dashboard_id) { FFaker::Lorem.word }
    let(:qrvey_dashboard_item) { {"pageOriginalid" => dashboard_id} }

    it "returns the dashboard's ID" do
      qrvey_dashboard_response = described_class.new(qrvey_dashboard_item)

      expect(qrvey_dashboard_response.dashboard_id).to eq dashboard_id
    end
  end

  describe "#can_edit?" do
    subject { qrvey_dashboard_response.can_edit?(user_id) }

    let(:qrvey_dashboard_response) { described_class.new(qrvey_dashboard_item) }
    let(:user_id) { create(:user).id }

    describe "when customAttributes are valid" do
      context "when the dashboard is shared with the user" do
        context "with edit permissions" do
          let(:qrvey_dashboard_item) do
            custom_attributes = QrveyBridge::CustomAttributes.new
            custom_attributes.owner_id = create(:user).id
            custom_attributes.share_with(user_id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR)

            custom_attributes.to_h
          end

          it { is_expected.to be true }
        end

        context "without edit permissions" do
          let(:qrvey_dashboard_item) do
            custom_attributes = QrveyBridge::CustomAttributes.new
            custom_attributes.owner_id = create(:user).id
            custom_attributes.share_with(user_id, QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER)

            custom_attributes.to_h
          end

          it { is_expected.to be false }
        end
      end

      context "when the user is the owner" do
        let(:qrvey_dashboard_item) do
          custom_attributes = QrveyBridge::CustomAttributes.new
          custom_attributes.owner_id = user_id

          custom_attributes.to_h
        end

        it { is_expected.to be true }
      end
    end

    describe "when customAttributes are invalid" do
      [
        {},
        {"customAttributes" => {}},
        {
          "customAttributes" => {
            "sharedWith" => {}
          }
        },
        {
          "customAttributes" => {
            "ownedBy" => -1
          }
        }
      ].each do |invalid_attributes|
        let(:qrvey_dashboard_item) { invalid_attributes }

        it { is_expected.to be false }
      end
    end
  end

  describe "#dashboard_shared_with_user?" do
    subject { qrvey_dashboard_response.dashboard_shared_with_user?(user_id) }

    let(:owner_id) { create(:user).id }
    let(:viewer_user_id) { create(:user).id }
    let(:editor_user_id) { create(:user).id }

    let(:qrvey_dashboard_response) { described_class.new(qrvey_dashboard_item) }
    let(:qrvey_dashboard_item) do
      custom_attributes = QrveyBridge::CustomAttributes.new
      custom_attributes.owner_id = owner_id
      custom_attributes.share_with_many(
        {
          viewer_user_id => QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER,
          editor_user_id => QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR
        }
      )

      custom_attributes.to_h
    end

    context "when the user_id belongs to the owner" do
      let(:user_id) { owner_id }

      it { is_expected.to be false }
    end

    context "when the user_id is found in customAttributes" do
      let(:user_id) { viewer_user_id }

      it { is_expected.to be true }
    end

    context "when the user_id is not found in customAttributes" do
      let(:user_id) { [owner_id + viewer_user_id + editor_user_id].max + 1 }

      it { is_expected.to be false }
    end

    describe "invalid data" do
      let(:user_id) { viewer_user_id }

      context "when the response object is missing sharedWith" do
        let(:qrvey_dashboard_item) { {"customAttributes" => { }} }

        it { is_expected.to be false }
      end

      context "when the response object is missing customAttributes" do
        let(:qrvey_dashboard_item) { {} }

        it { is_expected.to be false }
      end
    end
  end
end
