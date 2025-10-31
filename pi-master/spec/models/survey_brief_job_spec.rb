# frozen_string_literal: true
require 'spec_helper'

describe SurveyBriefJob do
  let(:survey) { create(:survey) }

  describe "validations" do
    [:pending, :in_progress].each do |status|
      context "when there is already a job for the same survey that is not done" do
        subject { described_class.new(status: status, survey: survey) }

        before do
          described_class.create(status: status, survey: survey)
        end

        it { is_expected.not_to be_valid }
      end
    end

    context "when the last job failed" do
      subject { described_class.new(status: :pending, survey: survey) }

      before do
        described_class.create(status: :failed, survey: survey)
      end

      it { is_expected.to be_valid }
    end

    context "when there is already a job for the same survey that is done" do
      let(:input) { "Please process this customer satisfaction survey..." }

      before do
        described_class.create(status: :done, survey: survey, input: input)
      end

      context "when the input is the same" do
        subject { described_class.new(status: :done, survey: survey, input: input) }

        it { is_expected.not_to be_valid }
      end

      context "when the input is different" do
        subject { described_class.new(status: :done, survey: survey, input: "Please process this user feedback survey...") }

        it { is_expected.to be_valid }
      end
    end
  end
end
