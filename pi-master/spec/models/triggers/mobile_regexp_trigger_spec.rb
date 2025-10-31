# frozen_string_literal: true
require "spec_helper"

describe MobileRegexpTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:mobile_regexp) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey, mobile_regexp: mobile_regexp) }
    let(:survey) { create(:survey) }
    let(:mobile_regexp) { "regex" }

    it { is_expected.to eq "Mobile view must match regex /#{mobile_regexp}/" }
  end
end
