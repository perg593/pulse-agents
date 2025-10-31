# frozen_string_literal: true
require 'spec_helper'

describe "SurveyRecommendations" do
  include Devise::Test::IntegrationHelpers

  describe "POST /surveys/:survey_id/recommendations" do
    let(:user) { create(:user) }
    let(:survey) { create(:survey, account: user.account) }

    let(:device_types) { %w(desktop mobile) }
    let(:date_range) { (1.week.ago..Time.current).to_s }
    let(:completion_url_filter) do
      {
        matcher: "contains",
        value: "checkout",
        cumulative: "true"
      }.to_json
    end
    let(:pageview_count_filter) do
      {
        comparator: "greater_than",
        value: "5"
      }.to_json
    end
    let(:visit_count_filter) do
      {
        comparator: "less_than",
        value: "10"
      }.to_json
    end

    before do
      sign_in user

      allow(GPT).to receive(:chat).and_return(
        {
          "choices" => [
            {
              "message" => {
                "content" => "[{\"title\":\"Test Recommendation\"}]"
              }
            }
          ]
        }
      )

      # Executing SurreyRecommendationWorker inline for testing
      Sidekiq::Testing.inline! do
        post "/surveys/#{survey.id}/recommendations", params: {
          device_types: device_types,
          date_range: date_range,
          completion_urls: [completion_url_filter],
          pageview_count: pageview_count_filter,
          visit_count: visit_count_filter
        }
      end
    end

    it "creates a survey recommendation with the correct filters" do
      filters = SurveyRecommendation.last.filters

      expect(filters["device_types"]).to match_array(device_types)

      expect(filters["date_range"]).to eq date_range

      completion_url = JSON.parse(filters["completion_urls"].first)
      expect(completion_url).to have_key("matcher")
      expect(completion_url["matcher"]).to eq("contains")
      expect(completion_url["value"]).to eq("checkout")
      expect(completion_url["cumulative"]).to eq("true")

      pageview_count = JSON.parse(filters["pageview_count"])
      expect(pageview_count["comparator"]).to eq("greater_than")
      expect(pageview_count["value"]).to eq('5')

      visit_count = JSON.parse(filters["visit_count"])
      expect(visit_count["comparator"]).to eq("less_than")
      expect(visit_count["value"]).to eq('10')
    end
  end
end
