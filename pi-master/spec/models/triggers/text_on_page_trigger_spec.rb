# frozen_string_literal: true
require "spec_helper"

describe TextOnPageTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_exclusion_of(:text_on_page_enabled).in_array([nil]) }
    it { is_expected.to validate_exclusion_of(:text_on_page_presence).in_array([nil]) }
    it { is_expected.to validate_presence_of(:text_on_page_selector) }
    it { is_expected.to validate_presence_of(:text_on_page_value) }
  end

  describe "#satisfied_with_page?" do
    subject { trigger.satisfied_with_page?(body) }

    let(:trigger) { create(:text_on_page_trigger, text_on_page_enabled: true, text_on_page_presence: true, survey: create(:survey), text_on_page_selector: "h1", text_on_page_value: "Hello") }

    context "when the text is found on the page" do
      let(:body) { Nokogiri::HTML("<h1>Hello World</h1>") }

      it { is_expected.to be true }

      context "when text_on_page_presence is false" do
        before do
          trigger.update(text_on_page_presence: false)
        end

        it { is_expected.to be false }
      end
    end

    context "when the text is not found on the page" do
      let(:body) { Nokogiri::HTML("<h1>Goodbye World</h1>") }

      it { is_expected.to be false }

      context "when texte_on_page_presence is false" do
        before do
          trigger.update(text_on_page_presence: false)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:text_on_page_selector) { "h1" }
    let(:text_on_page_value) { "Hello" }

    context "when text_on_page_presence is true" do
      let(:trigger) do
        create(:text_on_page_trigger,
               text_on_page_enabled: true,
               text_on_page_presence: true,
               text_on_page_selector: text_on_page_selector,
               text_on_page_value: text_on_page_value,
               survey: create(:survey))
      end

      it { is_expected.to eq "HTML element #{text_on_page_selector} must contain #{text_on_page_value}" }
    end

    context "when text_on_page_presence is false" do
      let(:trigger) do
        create(:text_on_page_trigger,
               text_on_page_enabled: true,
               text_on_page_presence: false,
               text_on_page_selector: text_on_page_selector,
               text_on_page_value: text_on_page_value,
               survey: create(:survey))
      end

      it { is_expected.to eq "HTML element #{text_on_page_selector} must not contain #{text_on_page_value}" }
    end
  end
end
