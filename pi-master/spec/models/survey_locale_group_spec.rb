# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe SurveyLocaleGroup do
  let(:timezone) { ActiveSupport::TimeZone['GMT'] }

  let(:viewed_impressions_enabled_at) { Time.current }
  let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }

  let(:base_survey) { create(:localized_survey, account: account) }
  let(:survey_locale_group) { base_survey.survey_locale_group }

  describe "destruction" do
    context "when a survey locale group is destroyed" do
      before do
        3.times do |i|
          survey = base_survey.duplicate
          survey.add_to_localization_group(survey_locale_group.id, "en-CA_#{i}")
          survey.save
        end

        @surveys = survey_locale_group.reload.surveys

        survey_locale_group.destroy
      end

      it "can be destroyed" do
        expect(described_class.count).to eq 0
      end

      it "unlocalizes all surveys in the group" do
        @surveys.each do |survey|
          expect(survey.localized?).to be false
        end
      end

      it "destroys all associated question and possible answer groups" do
        expect(QuestionLocaleGroup.count).to eq 0
        expect(PossibleAnswerLocaleGroup.count).to eq 0
      end
    end
  end

  describe "#blended_impressions_count" do
    def make_submissions(extras = {})
      # observer hasn't been enabled yet
      create(:submission, survey: base_survey, created_at: viewed_impressions_enabled_at - 1.day, **extras)

      # observer has been enabled for more than a day
      create(:submission, survey: base_survey, viewed_at: nil, created_at: viewed_impressions_enabled_at + 2.days, **extras)
      create(:submission, survey: base_survey, viewed_at: FFaker::Time.datetime, created_at: viewed_impressions_enabled_at + 2.days, **extras)

      # observer has been enabled for less than a day
      create(:submission, survey: base_survey, created_at: viewed_impressions_enabled_at + 0.5.day, **extras)
    end

    def it_calculates_accurate_blended_impressions(impressions_scope, filters = {})
      num_impressions = 0

      impressions_scope.each do |impression|
        if impression.created_at >= account.viewed_impressions_calculation_start_at
          num_impressions += 1 if impression.viewed_at?
        else
          num_impressions += 1
        end
      end

      expect(survey_locale_group.blended_impressions_count(filters: filters)).to eq num_impressions
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        scope = base_survey.impressions
        scope = Submission.filtered_submissions(scope, filters: filters)

        it_calculates_accurate_blended_impressions(scope, filters)
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_submissions and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_submissions({ filter_attribute => attribute_value })
        when :possible_answer_id
          # These are only meaningful for submissions, not impressions
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end

  describe '#submission_rate' do
    before do
      3.times do |n|
        survey = base_survey.duplicate
        survey.add_to_localization_group(base_survey.survey_locale_group_id, "en_gb_#{n}")

        create_list(:submission, 3, survey: survey, created_at: viewed_impressions_enabled_at - 1.day)
        create_list(:submission, 3, survey: survey, created_at: viewed_impressions_enabled_at, viewed_at: FFaker::Time.datetime)
        create_list(:submission, 3, survey: survey, created_at: viewed_impressions_enabled_at + 1.day, viewed_at: FFaker::Time.datetime)
      end

      @survey_locale_group = base_survey.survey_locale_group
    end

    it_behaves_like "filter sharing" do
      def make_impression(extras = {})
        create(:submission, survey: base_survey, **extras)
      end

      def make_impression_records(filter_attribute = nil, attribute_value = nil)
        make_impression and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_impression({ filter_attribute => attribute_value })
        when :possible_answer_id
          # These are only meaningful for submissions, not impressions
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end

      def it_filters(filter)
        expected_impressions_count = @survey_locale_group.blended_impressions_count(filters: filter).to_f
        expected_rate = expected_impressions_count.zero? ? 0 : (@survey_locale_group.submissions_count(filters: filter) / expected_impressions_count).round(2)

        expect(@survey_locale_group.submission_rate(filters: filter)).to eq expected_rate
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_impression_records(filter_attribute, attribute_value)
      end
    end
  end

  describe '#base_questions' do
    it 'returns a collection of base questions in the order of position' do
      base_survey = create(:localized_survey)
      survey_locale_group = base_survey.survey_locale_group
      survey = base_survey.duplicate
      survey.add_to_localization_group(survey_locale_group.id, "en_gb")
      base_questions = base_survey.questions # sorted by position

      # #base_questions returns an Array object, so it can't be compared directly with an ActiveRecord::Relation object
      expect(survey_locale_group.base_questions).to eq base_questions.to_a
    end
  end

  describe "#report_stats" do
    before do
      @other_survey = base_survey.duplicate
      @other_survey.add_to_localization_group(survey_locale_group.id, "en_gb")
    end

    def make_answers(submission_extras: {})
      [base_survey, @other_survey].each do |survey|
        create(:submission, survey: survey, **submission_extras)

        submission = create(:submission, survey: survey, created_at: viewed_impressions_enabled_at, viewed_at: Time.current, **submission_extras)
        create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.possible_answers.first)
      end
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        result = survey_locale_group.report_stats(filters: filters).records

        expect(result.first.impression_count).to eq(survey_locale_group.impressions_count(filters: filters))
        expect(result.first.viewed_impression_count).to eq(survey_locale_group.viewed_impressions_count(filters: filters))
        expect(result.first.submission_count).to eq(survey_locale_group.submissions_count(filters: filters))
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answers and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_answers(submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(base_survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end
end
