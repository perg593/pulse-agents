# frozen_string_literal: true
require 'spec_helper'

describe SurveyRecommendationsChannel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user

    subscribe survey_id: survey_id
  end

  context "when user has access to the survey" do
    let(:survey_id) { create(:survey, account: user.account).id }

    it "subscribes to the stream" do
      expect(subscription).to be_confirmed

      expect(subscription).to have_stream_from("survey_recommendations_#{survey_id}")
    end
  end

  context "when user does not have access to the survey" do
    let(:survey_id) { create(:survey).id }

    it "rejects the subscription" do
      expect(subscription).to be_rejected
    end
  end

  context "when survey_id is not provided" do
    let(:survey_id) { nil }

    it "rejects the subscription" do
      expect(subscription).to be_rejected
    end
  end

  context "when survey_id is invalid" do
    let(:survey_id) { -1 }

    it "rejects the subscription" do
      expect(subscription).to be_rejected
    end
  end
end
