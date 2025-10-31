# frozen_string_literal: true
require "spec_helper"

describe MobileInstallTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:mobile_days_installed) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey, mobile_days_installed: mobile_days_installed) }
    let(:survey) { create(:survey) }
    let(:mobile_days_installed) { 10 }

    it { is_expected.to eq "Mobile app must have been installed for at least #{mobile_days_installed} days" }
  end
end
