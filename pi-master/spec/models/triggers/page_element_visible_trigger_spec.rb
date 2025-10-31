# frozen_string_literal: true
require "spec_helper"

describe PageElementVisibleTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_exclusion_of(:render_after_element_visible_enabled).in_array([nil]) }
    it { is_expected.to validate_presence_of(:render_after_element_visible) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:survey) { create(:survey) }

    context "when render_after_element_visible_enabled is true" do
      let(:trigger) { described_class.new(survey: survey, render_after_element_visible_enabled: true, render_after_element_visible: "#target_element_selector") }

      it { is_expected.to eq "Element '#target_element_selector' must be visible" }
    end

    context "when render_after_element_visible_enabled is false" do
      let(:trigger) { described_class.new(survey: survey, render_after_element_visible_enabled: false) }

      it { is_expected.to be_nil }
    end
  end
end
