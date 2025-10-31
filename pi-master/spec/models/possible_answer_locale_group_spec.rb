# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe PossibleAnswerLocaleGroup do
  describe "validations" do
    it_behaves_like "color validation" do
      subject { create(:possible_answer_locale_group) }

      let(:attribute_to_validate) { :report_color }
    end
  end

  describe "#answers_count" do
    before do
      base_survey = create(:localized_survey)

      survey_locale_group = base_survey.survey_locale_group
      duplicate_survey = base_survey.duplicate
      duplicate_survey.save
      duplicate_survey.add_to_localization_group(survey_locale_group.id, "en-ca")

      @possible_answer_locale_group = base_survey.questions.first.possible_answers.sort_by_position.first.possible_answer_locale_group
    end

    def make_answer(submission_extras: {}, answer_extras: {})
      @possible_answer_locale_group.possible_answers.each do |possible_answer|
        submission = create(:submission, **submission_extras)
        create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
      end
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        expect(@possible_answer_locale_group.answers_count(filters: filters)).to eq(
          @possible_answer_locale_group.possible_answers.sum { |possible_answer| possible_answer.answers_count(filters: filters) }
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
          make_possible_answer_filter_records(@possible_answer_locale_group.base_possible_answer.question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end
end
