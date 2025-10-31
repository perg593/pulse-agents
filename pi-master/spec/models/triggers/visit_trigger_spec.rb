# frozen_string_literal: true
require "spec_helper"

describe VisitTrigger do
  describe "validations" do
    describe "visitor_type" do
      subject { described_class.new(survey: create(:survey)) }

      it { is_expected.to define_enum_for(:visitor_type).with_values([:all_visitors, :first_time_visitors, :repeat_visitors]) }
    end

    describe "visits_count" do
      context "when visitor_type is repeat_visitors" do
        subject { described_class.new(survey: create(:survey), visitor_type: :repeat_visitors) }

        it { is_expected.to validate_numericality_of(:visits_count).is_greater_than_or_equal_to(0) }
      end
    end
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:survey) { create(:survey) }

    context "when visitor_type is all_visitors" do
      let(:trigger) { described_class.new(survey: survey, visitor_type: :all_visitors) }

      it { is_expected.to eq "All visitors" }
    end

    context "when visitor_type is first_time_visitors" do
      let(:trigger) { described_class.new(survey: survey, visitor_type: :first_time_visitors) }

      it { is_expected.to eq "First time visitors" }
    end

    context "when visitor_type is repeat_visitors" do
      let(:visits_count) { 5 }
      let(:trigger) { described_class.new(survey: survey, visitor_type: :repeat_visitors, visits_count: visits_count) }

      it { is_expected.to eq "Repeat visitors with at least #{visits_count} visits" }
    end
  end
end
