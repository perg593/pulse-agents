# frozen_string_literal: true
require "spec_helper"

describe PageAfterSecondsTrigger do
  describe "validations" do
    describe "render_after_x_seconds_enabled" do
      subject { described_class.new(survey: create(:survey)) }

      it { is_expected.to validate_exclusion_of(:render_after_x_seconds_enabled).in_array([nil]) }
      it { is_expected.to validate_numericality_of(:render_after_x_seconds).is_greater_than(0) }
    end
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:survey) { create(:survey) }

    context "when render_after_x_seconds_enabled is false" do
      let(:trigger) { described_class.new(survey: survey, render_after_x_seconds_enabled: false) }

      it { is_expected.to be_nil }
    end

    context "when render_after_x_seconds_enabled is true" do
      let(:render_after_x_seconds) { 5 }
      let(:trigger) { described_class.new(survey: survey, render_after_x_seconds_enabled: true, render_after_x_seconds: render_after_x_seconds) }

      it { is_expected.to eq "#{render_after_x_seconds} seconds have elapsed" }
    end
  end
end
