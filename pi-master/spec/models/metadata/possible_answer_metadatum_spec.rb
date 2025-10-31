# frozen_string_literal: true
require 'spec_helper'

describe Metadata::PossibleAnswerMetadatum do
  describe "validations" do
    let(:possible_answer_metadatum) { described_class.new }

    it { expect(possible_answer_metadatum).to validate_presence_of(:name) }
    it { expect(possible_answer_metadatum).to belong_to(:possible_answer).class_name("PossibleAnswer") }
  end

  context "when another possible answer in the question has the same metadatum.name" do
    let(:possible_answer_metadatum) { described_class.new(name: "name", possible_answer: create(:possible_answer)) }

    before do
      question = possible_answer_metadatum.possible_answer.question
      create(:possible_answer_metadatum, name: possible_answer_metadatum.name, possible_answer: create(:possible_answer, question: question))
    end

    it "is invalid" do
      expect(possible_answer_metadatum.valid?).to be false
    end
  end
end
