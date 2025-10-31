# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe QuestionLocaleGroup do
  describe "destruction" do
    let(:base_survey) { create(:localized_survey) }
    let(:survey_locale_group) { base_survey.survey_locale_group }
    let(:account) { base_survey.account }

    context "when a question locale group is destroyed" do
      before do
        survey_locale_group.question_locale_groups.each(&:destroy)
      end

      it "destroys all associated possible answer groups" do
        expect(PossibleAnswerLocaleGroup.count).to eq 0
      end
    end
  end

  describe "#answers_count" do
    before do
      base_survey = create(:localized_survey)

      survey_locale_group = base_survey.survey_locale_group
      duplicate_survey = base_survey.duplicate
      duplicate_survey.save
      duplicate_survey.add_to_localization_group(survey_locale_group.id, "en-ca")

      @question_locale_group = base_survey.questions.first.question_locale_group
    end

    def make_answer(submission_extras: {}, answer_extras: {})
      @question_locale_group.questions.each do |question|
        possible_answer = question.possible_answers.first
        submission = create(:submission, **submission_extras)
        create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
      end
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        expect(@question_locale_group.answers_count(filters: filters)).to eq(
          @question_locale_group.questions.sum { |question| question.answers_count(filters: filters) }
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answer and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(answer_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_answer(submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(@question_locale_group.base_question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end
end
