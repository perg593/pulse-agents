# frozen_string_literal: true
require "spec_helper"

describe PageElementClickedTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:render_after_element_clicked) }
    it { is_expected.to validate_exclusion_of(:render_after_element_clicked_enabled).in_array([nil]) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:selector) { "#form_submit_button" }

    context "when render_after_element_clicked_enabled is true" do
      let(:trigger) { described_class.new(survey: create(:survey), render_after_element_clicked_enabled: true, render_after_element_clicked: selector) }

      it { is_expected.to eq "Element '#{selector}' was clicked" }
    end

    context "when render_after_element_clicked_enabled is false" do
      let(:trigger) { described_class.new(survey: create(:survey), render_after_element_clicked_enabled: false, render_after_element_clicked: selector) }

      it { is_expected.to be_nil }
    end
  end
end
