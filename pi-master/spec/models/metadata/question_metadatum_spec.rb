# frozen_string_literal: true
require 'spec_helper'

describe Metadata::QuestionMetadatum do
  describe "validations" do
    let(:question_metadatum) { described_class.new }

    it { expect(question_metadatum).to validate_presence_of(:name) }
    it { expect(question_metadatum).to belong_to(:question).class_name("Question") }

    context "when another question in the survey has the same metadatum.name" do
      let(:question_metadatum) { described_class.new(name: "name", question: create(:question)) }

      before do
        survey = question_metadatum.question.survey
        create(:question_metadatum, name: question_metadatum.name, question: create(:question, survey: survey))
      end

      it "is invalid" do
        expect(question_metadatum.valid?).to be false
      end
    end
  end
end
