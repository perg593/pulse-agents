# frozen_string_literal: true
require "spec_helper"

describe UrlTrigger do
  describe "URL stripping" do
    before do
      @trigger = described_class.new
      @trigger.survey = create(:survey)
    end

    context "when http" do
      before do
        @trigger.url = "http://pulseinsights.com"
        @trigger.save
      end

      it "removes the leading 'http://'" do
        expect(@trigger.url).to eq "pulseinsights.com"
      end
    end

    context "when https" do
      before do
        @trigger.url = "https://pulseinsights.com"
        @trigger.save
      end

      it "removes the leading 'https://'" do
        expect(@trigger.url).to eq "pulseinsights.com"
      end
    end
  end

  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:url) }
  end

  describe "#url_passes?" do
    subject { trigger.url_passes?(url) }

    let(:trigger) { create(:url_trigger, url: "pulse", survey: create(:survey)) }

    context "when the URL includes the trigger's url" do
      let(:url) { "http://pulseinsights.com" }

      it { is_expected.to be true }

      context "when excluded is true" do
        before do
          trigger.update!(excluded: true)
        end

        it { is_expected.to be false }
      end
    end

    context "when the URL does not include the trigger's url" do
      let(:url) { "http://poolseinsights.org" }

      it { is_expected.to be false }

      context "when excluded is true" do
        before do
          trigger.update!(excluded: true)
        end

        it { is_expected.to be true }
      end
    end
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:url) { "pulse" }

    context "when excluded is true" do
      let(:trigger) { create(:url_trigger, url: url, survey: create(:survey), excluded: true) }

      it { is_expected.to eq "Must not include URL: #{url}" }
    end

    context "when excluded is false" do
      let(:trigger) { create(:url_trigger, url: url, survey: create(:survey), excluded: false) }

      it { is_expected.to eq "Must include URL: #{url}" }
    end
  end
end
