# frozen_string_literal: true
require "spec_helper"

describe PreviousAnswerTrigger do
  describe "validations" do
    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_presence_of(:previous_possible_answer_id) }
    it { is_expected.to validate_presence_of(:previous_answered_survey_id) }
  end

  describe "#summarize" do
    subject { trigger.summarize }

    let(:trigger) do
      described_class.new(survey: survey, previous_answered_survey_id: previous_answered_survey.id, previous_possible_answer_id: previous_possible_answer.id)
    end

    let(:survey) { create(:survey) }
    let(:previous_answered_survey) { create(:survey) }
    let(:previous_possible_answer) { previous_answered_survey.possible_answers.first }

    it { is_expected.to eq "Answered survey #{previous_answered_survey.name} with possible answer #{previous_possible_answer.content}" }
  end
end
