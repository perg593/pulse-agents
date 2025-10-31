# frozen_string_literal: true
require "spec_helper"

describe PageScrollTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_exclusion_of(:render_after_x_percent_scroll_enabled).in_array([nil]) }
    it { is_expected.to validate_numericality_of(:render_after_x_percent_scroll).is_less_than_or_equal_to(100) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:survey) { create(:survey) }

    context "when render_after_x_percent_scroll_enabled is false" do
      let(:trigger) { described_class.new(survey: survey, render_after_x_percent_scroll_enabled: false) }

      it { is_expected.to be_nil }
    end

    context "when render_after_x_percent_scroll_enabled is true" do
      let(:render_after_x_percent_scroll) { 5 }
      let(:trigger) { described_class.new(survey: survey, render_after_x_percent_scroll_enabled: true, render_after_x_percent_scroll: render_after_x_percent_scroll) }

      it { is_expected.to eq "After #{render_after_x_percent_scroll}% of the page has been scrolled" }
    end
  end
end
