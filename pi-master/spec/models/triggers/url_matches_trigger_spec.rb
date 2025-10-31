# frozen_string_literal: true
require "spec_helper"

describe UrlMatchesTrigger do
  describe "URL stripping" do
    before do
      @trigger = described_class.new
      @trigger.survey = create(:survey)
    end

    context "when URL ends in '/' (forward slash)" do
      before do
        @trigger.url_matches = "http://pulseinsights.com/abc/"
        @trigger.save
      end

      it "removes the final '/' (forward slash)" do
        expect(@trigger.url_matches).to eq "pulseinsights.com/abc"
      end
    end

    context "when http" do
      before do
        @trigger.url_matches = "http://pulseinsights.com"
        @trigger.save
      end

      it "removes the leading 'http://'" do
        expect(@trigger.url_matches).to eq "pulseinsights.com"
      end
    end

    context "when https" do
      before do
        @trigger.url_matches = "https://pulseinsights.com"
        @trigger.save
      end

      it "removes the leading 'https://'" do
        expect(@trigger.url_matches).to eq "pulseinsights.com"
      end
    end
  end

  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:url_matches) }
  end

  describe "#url_passes?" do
    subject { trigger.url_passes?(url) }

    let(:trigger) { create(:url_matches_trigger, url_matches: "http://pulseinsights.com", survey: create(:survey)) }

    context "when the URL matches the trigger's url" do
      let(:url) { "http://pulseinsights.com" }

      it { is_expected.to be true }

      context "when excluded is true" do
        before do
          trigger.update!(excluded: true)
        end

        it { is_expected.to be false }
      end
    end

    context "when the URL does not match the trigger's url" do
      let(:url) { "http://pulseinsights.com/marketing" }

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

    let(:url_matches) { "http://pulseinsights.com" }

    context "when excluded is true" do
      let(:trigger) { create(:url_matches_trigger, url_matches: url_matches, survey: create(:survey), excluded: true) }

      it { is_expected.to eq "URL must not match pulseinsights.com" }
    end

    context "when excluded is false" do
      let(:trigger) { create(:url_matches_trigger, url_matches: url_matches, survey: create(:survey), excluded: false) }

      it { is_expected.to eq "URL must match pulseinsights.com" }
    end
  end
end
