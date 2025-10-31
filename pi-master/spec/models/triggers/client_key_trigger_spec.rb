# frozen_string_literal: true
require "spec_helper"

describe ClientKeyTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_exclusion_of(:client_key_presence).in_array([nil]) }
  end

  describe "#summarize" do
    subject { described_class.new(survey: create(:survey), client_key_presence: true).summarize }

    it { is_expected.to eq "Client key must be present" }
  end
end
