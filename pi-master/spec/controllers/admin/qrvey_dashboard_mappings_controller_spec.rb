# frozen_string_literal: true
require 'spec_helper'

describe Admin::QrveyDashboardMappingsController do
  def assert_no_gaps_in_dashboard_mapping_positions
    expected_positions = [*1..QrveyDashboardMapping.all.count]

    expect(QrveyDashboardMapping.all.pluck(:position).sort).to match_array(expected_positions)
  end

  describe "#change_position" do
    before do
      user = create(:admin)
      sign_in user

      @qrvey_dashboard_mappings = 10.times.map do |i|
        create(:qrvey_dashboard_mapping, position: i + 1)
      end
    end

    context "when moving dashboard mapping to a higher position" do
      before do
        @dashboard_mapping_to_move = @qrvey_dashboard_mappings[4]
        @new_position = 7

        post :change_position, params: { id: @dashboard_mapping_to_move.id, new_position: @new_position}
      end

      it "leaves no gap in positions" do
        assert_no_gaps_in_dashboard_mapping_positions
      end

      it "changes the position of the dashboard mapping" do
        expect(@dashboard_mapping_to_move.reload.position).to eq(@new_position)
      end

      it "shifts the position of the dashboard_mappings in between the source and destination positions" do
        expect(@qrvey_dashboard_mappings[0].reload.position).to eq(1)
        expect(@qrvey_dashboard_mappings[1].reload.position).to eq(2)
        expect(@qrvey_dashboard_mappings[2].reload.position).to eq(3)
        expect(@qrvey_dashboard_mappings[3].reload.position).to eq(4)

        expect(@qrvey_dashboard_mappings[4].reload.position).to eq(7)
        expect(@qrvey_dashboard_mappings[5].reload.position).to eq(5)
        expect(@qrvey_dashboard_mappings[6].reload.position).to eq(6)

        expect(@qrvey_dashboard_mappings[7].reload.position).to eq(8)
        expect(@qrvey_dashboard_mappings[8].reload.position).to eq(9)
        expect(@qrvey_dashboard_mappings[9].reload.position).to eq(10)
      end
    end

    context "when moving dashboard mapping to a lower position" do
      before do
        @dashboard_mapping_to_move = @qrvey_dashboard_mappings[7]
        @new_position = 3

        post :change_position, params: { id: @dashboard_mapping_to_move.id, new_position: @new_position}
      end

      it "leaves no gap in positions" do
        assert_no_gaps_in_dashboard_mapping_positions
      end

      it "changes the position of the dashboard" do
        expect(@dashboard_mapping_to_move.reload.position).to eq(@new_position)
      end

      it "shifts the position of the dashboard mappings in between the source and destination positions" do
        expect(@qrvey_dashboard_mappings[0].reload.position).to eq(1)
        expect(@qrvey_dashboard_mappings[1].reload.position).to eq(2)

        expect(@qrvey_dashboard_mappings[2].reload.position).to eq(4)
        expect(@qrvey_dashboard_mappings[3].reload.position).to eq(5)
        expect(@qrvey_dashboard_mappings[4].reload.position).to eq(6)
        expect(@qrvey_dashboard_mappings[5].reload.position).to eq(7)
        expect(@qrvey_dashboard_mappings[6].reload.position).to eq(8)
        expect(@qrvey_dashboard_mappings[7].reload.position).to eq(3)

        expect(@qrvey_dashboard_mappings[8].reload.position).to eq(9)
        expect(@qrvey_dashboard_mappings[9].reload.position).to eq(10)
      end
    end
  end

  describe "#update" do
    before do
      user = create(:admin)
      sign_in user
    end

    it "updates an existing record" do
      qrvey_dashboard_mapping = create(:qrvey_dashboard_mapping)

      old_qrvey_name = qrvey_dashboard_mapping.qrvey_name
      new_pi_name = FFaker::Lorem.unique.sentence

      patch :update, params: { id: qrvey_dashboard_mapping.id, qrvey_dashboard_mapping: { pi_name: new_pi_name }}

      qrvey_dashboard_mapping = QrveyDashboardMapping.first

      expect(qrvey_dashboard_mapping.pi_name).to eq(new_pi_name)
      expect(qrvey_dashboard_mapping.qrvey_name).to eq(old_qrvey_name)

      assert_response :success
    end
  end

  describe "#create" do
    before do
      user = create(:admin)
      sign_in user
    end

    it "creates a new record" do
      qrvey_name = FFaker::Lorem.unique.sentence
      pi_name = FFaker::Lorem.unique.sentence

      post :create, params: { qrvey_dashboard_mapping: { qrvey_name: qrvey_name, pi_name: pi_name, position: 42 }}

      expect(QrveyDashboardMapping.count).to eq(1)

      qrvey_dashboard_mapping = QrveyDashboardMapping.first

      expect(qrvey_dashboard_mapping.qrvey_name).to eq(qrvey_name)
      expect(qrvey_dashboard_mapping.pi_name).to eq(pi_name)
      expect(qrvey_dashboard_mapping.position).to eq(1)

      assert_response :success
    end
  end

  describe "#destroy" do
    before do
      user = create(:admin)
      @qrvey_dashboard_mapping = create(:qrvey_dashboard_mapping)

      3.times do
        create(:qrvey_dashboard_mapping, position: QrveyDashboardMapping.maximum(:position) + 1)
      end

      sign_in user

      delete :destroy, params: { id: @qrvey_dashboard_mapping.id }
    end

    it "destroys the record" do
      expect(QrveyDashboardMapping.find_by_id(@qrvey_dashboard_mapping.id)).to be_nil
    end

    it "returns all dashboard mappings in position order" do
      assert_response :success

      json_response = JSON.parse(response.body)

      expected_dashboard_mappings = QrveyDashboardMapping.all.order(:position).map do |db_dashboard_mapping|
        {
          "id" => db_dashboard_mapping.id,
          "position" => db_dashboard_mapping.position,
          "qrveyName" => db_dashboard_mapping.qrvey_name,
          "piName" => db_dashboard_mapping.pi_name
        }
      end

      expect(json_response["qrveyDashboardMappings"]).to match_array expected_dashboard_mappings
    end

    it "leaves no gap in positions" do
      assert_no_gaps_in_dashboard_mapping_positions
    end
  end
end
