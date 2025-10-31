# frozen_string_literal: true
require "spec_helper"

describe PseudoEventTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:pseudo_event) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:pseudo_event) { "pi-feedback-tab" }
    let(:trigger) { described_class.new(survey: create(:survey), pseudo_event: pseudo_event) }

    it { is_expected.to eq "When the survey is manually triggered with: #{pseudo_event}" }
  end
end
