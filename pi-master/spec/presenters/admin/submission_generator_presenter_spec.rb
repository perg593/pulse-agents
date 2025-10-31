# frozen_string_literal: true
require 'spec_helper'

describe Admin::SubmissionGeneratorPresenter do
  include Rails.application.routes.url_helpers

  let(:survey) { create(:survey) }
  let(:presenter) { described_class.new }

  describe "#props" do
    let(:props) { presenter.props }

    it "returns a URL to submit the form to" do
      expect(props[:formUrl]).to eq sample_generator_admin_submissions_path
    end

    it "returns a URL to look up questions with" do
      expect(props[:questionLookupUrl]).to eq admin_questions_path
    end
  end

  describe "#questions" do
    let(:result) { presenter.questions(survey.id) }

    it "contains an entry for each of the survey's questions" do
      expect(result.count).to eq survey.questions.count

      result_question_ids = result.map { |result_question| result_question[:id] }

      expect(result_question_ids).to match_array survey.questions.pluck(:id)
    end

    it "returns questions in position order" do
      survey.questions.each_with_index do |question, question_index|
        result_question = result[question_index]

        expect(result_question[:id]).to eq question.id
      end
    end

    it "returns question content" do
      result.each do |question|
        expect(question[:content]).to eq Question.find(question[:id]).content
      end
    end

    describe "possible_answers" do
      it "contains an entry for each question's possible answers" do
        expect(result.sum { |question| question[:possibleAnswers].count }).to eq survey.possible_answers.count

        result_possible_answer_ids = result.map { |question| question[:possibleAnswers].map { |possible_answer| possible_answer[:id] } }.flatten

        expect(result_possible_answer_ids).to match_array survey.possible_answers.pluck(:id)
      end

      it "returns possible answers in position order" do
        survey.questions.each_with_index do |question, question_index|
          result_question = result[question_index]

          question.possible_answers.sort_by_position.each_with_index do |possible_answer, possible_answer_index|
            result_possible_answer = result_question[:possibleAnswers][possible_answer_index]

            expect(result_possible_answer[:id]).to eq possible_answer.id
          end
        end
      end

      it "returns possible answers content" do
        result.each do |question|
          question[:possibleAnswers].each_with_index do |possible_answer, possible_answer_index|
            result_possible_answer = question[:possibleAnswers][possible_answer_index]

            expect(result_possible_answer[:content]).to eq PossibleAnswer.find(possible_answer[:id]).content
          end
        end
      end
    end
  end
end
