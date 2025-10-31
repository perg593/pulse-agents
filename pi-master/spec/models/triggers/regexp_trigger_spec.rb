# frozen_string_literal: true
require "spec_helper"

describe RegexpTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:regexp) }
  end

  describe "#url_passes?" do
    subject { trigger.url_passes?(url) }

    let(:trigger) { create(:regexp_trigger, regexp: "puls\\dinsight\\d", survey: create(:survey)) }

    context "when the URL matches the regexp" do
      let(:url) { "http://puls3insight5.com" }

      it { is_expected.to be true }

      context "when excluded is true" do
        before do
          trigger.update!(excluded: true)
        end

        it { is_expected.to be false }
      end
    end

    context "when the URL does not match the regexp" do
      let(:url) { "http://pulseinsights.com" }

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

    context "when excluded is true" do
      let(:trigger) { create(:regexp_trigger, regexp: "puls\\dinsight\\d", survey: create(:survey), excluded: true) }

      it { is_expected.to eq "URL must not match puls\\dinsight\\d" }
    end

    context "when excluded is false" do
      let(:trigger) { create(:regexp_trigger, regexp: "puls\\dinsight\\d", survey: create(:survey), excluded: false) }

      it { is_expected.to eq "URL must match puls\\dinsight\\d" }
    end
  end
end
