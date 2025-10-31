# frozen_string_literal: true
require "spec_helper"

describe MobileLaunchTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:mobile_launch_times) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey, mobile_launch_times: mobile_launch_times) }
    let(:survey) { create(:survey) }
    let(:mobile_launch_times) { 10 }

    it { is_expected.to eq "User must have launched the app at least #{mobile_launch_times} times" }
  end
end
