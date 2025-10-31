# frozen_string_literal: true
require "spec_helper"

describe GeoTrigger do
  describe "validations" do
    describe "geo_country" do
      subject { described_class.new(survey: create(:survey)) }

      it { is_expected.to validate_inclusion_of(:geo_country).in_array(described_class.geoip_countries) }
    end

    describe "geo_dma" do
      context "when geo_country is 'United States'" do
        subject { described_class.new(survey: create(:survey), geo_country: "United States") }

        let(:valid_geo_states_and_dma_values) { described_class.geoip_states + described_class.dma.map(&:last).flatten }

        it { is_expected.to validate_inclusion_of(:geo_state_or_dma).in_array(valid_geo_states_and_dma_values).allow_nil }
      end

      context "when geo_country is not 'United States'" do
        subject { described_class.new(survey: create(:survey), geo_country: "Canada") }

        it { is_expected.to validate_absence_of(:geo_state_or_dma) }
      end
    end
  end

  describe "#summarize" do
    let(:survey) { create(:survey) }

    context "when geo_country is 'Canada'" do
      subject { trigger.summarize }

      let(:geo_country) { "Canada" }
      let(:trigger) { described_class.new(survey: survey, geo_country: geo_country) }

      it { is_expected.to eq "Pageview from #{geo_country}" }

      context "when geo_state_or_dma is present" do
        let(:geo_state_or_dma) { "Ontario" }
        let(:trigger) { described_class.new(survey: survey, geo_country: geo_country, geo_state_or_dma: geo_state_or_dma) }

        it { is_expected.to eq "Pageview from #{geo_country}: #{geo_state_or_dma}" }
      end
    end
  end
end
