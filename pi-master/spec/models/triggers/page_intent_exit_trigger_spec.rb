# frozen_string_literal: true
require "spec_helper"

describe PageIntentExitTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_exclusion_of(:render_after_intent_exit_enabled).in_array([nil]) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) { described_class.new(survey: survey) }
    let(:survey) { create(:survey) }

    it { is_expected.to eq "When the user's intent to exit was detected" }
  end
end
