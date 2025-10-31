# frozen_string_literal: true
require "spec_helper"

describe DeviceDataTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    device_data_matchers = %w(
      is
      is_not
      contains
      does_not_contain
      is_true
      is_not_true
      is_more_than
      is_equal_or_more_than
      is_equal_or_less_than
      is_less_than
    )

    it { is_expected.to validate_inclusion_of(:device_data_matcher).in_array(device_data_matchers) }

    it { is_expected.to validate_presence_of(:device_data_key) }
    it { is_expected.to validate_exclusion_of(:device_data_mandatory).in_array([nil]) }
  end

  describe "device_data_value" do
    context "when device_data_matcher requires no value" do
      %w(is_true is_not_true).each do |matcher|
        subject { described_class.new(survey: create(:survey), device_data_matcher: matcher) }

        it { is_expected.to validate_absence_of(:device_data_value) }
      end
    end

    context "when device_data_matcher requires a value" do
      %w(
        contains
        does_not_contain
        is_true
        is_not_true
        is_more_than
        is_equal_or_more_than
        is_equal_or_less_than
        is_less_than
      ).each do |matcher|
        subject { described_class.new(survey: create(:survey), device_data_matcher: matcher) }

        it { is_expected.to validate_presence_of(:device_data_value) }
      end
    end
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:survey) { create(:survey) }
    let(:device_data_key) { "age" }
    let(:device_data_matcher) { "is" }
    let(:device_data_value) { "42" }
    let(:trigger) { described_class.new(survey: survey, device_data_key: device_data_key, device_data_matcher: device_data_matcher, device_data_value: device_data_value) }

    it { is_expected.to eq "Device data key '#{device_data_key}' #{device_data_matcher} '#{device_data_value}'" }
  end
end
