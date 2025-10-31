# frozen_string_literal: true
require "spec_helper"

describe MobilePageviewTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:mobile_pageview) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey, mobile_pageview: mobile_pageview) }
    let(:survey) { create(:survey) }
    let(:mobile_pageview) { "google.com" }

    it { is_expected.to eq "Mobile view must match #{mobile_pageview}" }
  end
end
