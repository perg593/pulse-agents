# frozen_string_literal: true
require "spec_helper"

describe PageviewTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_numericality_of(:pageviews_count).is_greater_than_or_equal_to(0) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey, pageviews_count: pageviews_count) }
    let(:survey) { create(:survey) }
    let(:pageviews_count) { 10 }

    it { is_expected.to eq "With at least #{pageviews_count} pageviews" }
  end
end
