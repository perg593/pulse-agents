# frozen_string_literal: true

require 'filter_spec_helper'
require 'spec_helper'

describe Answer do
  before do
    Survey.delete_all
    described_class.delete_all
    Question.delete_all
    Submission.delete_all
    PossibleAnswer.delete_all
    Device.delete_all
    described_class.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  describe 'Scopes' do
    describe 'auto-tag-eligible' do
      it 'filters out answers that have been tagged' do
        5.times { create(:applied_tag, answer: create(:free_text_answer)) }

        untagged_answers = 5.times.map { create(:free_text_answer) }

        expect(described_class.auto_tag_eligible.ids).to match_array untagged_answers.pluck(:id)
      end
    end
  end

  describe 'Before destroy' do
    before do
      @survey = create(:survey)
      question = create(:question, survey: @survey)
      question2 = create(:question, survey: @survey)
      device = create(:device, udid: udid)
      @submission = create(:submission, device_id: device.id, survey_id: @survey.id, closed_by_user: true)

      create(:answer, question_id: question.id, submission_id: @submission.id, possible_answer_id: question.possible_answers.first.id)
      create(:answer, question_id: question2.id, submission_id: @submission.id, possible_answer_id: question.possible_answers.last.id)
    end

    it 'recalculates submission#answers_count' do
      expect(@submission.reload.answers_count).to eq 2

      @submission.answers.last.destroy

      expect(@submission.reload.answers_count).to eq 1
    end

    it 'destroys submission if answers_count.zero?' do
      @submission.reload.answers.last.destroy
      @submission.reload.answers.last.destroy

      expect(@survey.reload.submissions.count).to eq 0
    end
  end

  describe 'After destroy' do
    it_behaves_like 'Qrvey Synchronization callbacks' do
      def trigger_record
        @trigger_record ||= create(:answer)
      end
    end
  end

  describe 'Duplicates' do
    let(:submission) { create(:submission) }

    context 'when submission_id and question_id are the same for answers to a single choice question' do
      it 'rolls back a CREATE statement' do
        question = create(:question)

        possible_answer = question.reload.possible_answers.first
        possible_answer2 = question.reload.possible_answers.last
        expect(possible_answer.id).not_to eq possible_answer2.id

        described_class.create!(submission: submission, question: question, possible_answer: possible_answer)

        error_message = /duplicate key value violates unique constraint "index_answers_on_sub_id_and_q_id_except_for_multi_choice"/
        expect do
          described_class.create!(submission: submission, question: question, possible_answer: possible_answer2)
        end.to raise_error(ActiveRecord::StatementInvalid, error_message)
      end
    end

    context 'when submission_id and question_id are the same for answers to a multiple choices question' do
      it 'executes a CREATE statement successfully' do
        question = create(:multiple_choices_question)

        possible_answer = question.reload.possible_answers.first
        possible_answer2 = question.reload.possible_answers.last
        expect(possible_answer.id).not_to eq possible_answer2.id

        expect(described_class.count).to eq 0
        described_class.create!(submission: submission, question: question, possible_answer: possible_answer)
        described_class.create!(submission: submission, question: question, possible_answer: possible_answer2)
        expect(described_class.count).to eq 2
      end
    end

    context 'when submission_id, question_id and possible_answer_id are the same for answers to a multiple choices question' do
      it 'rolls back a CREATE statement' do
        question = create(:multiple_choices_question)
        possible_answer = question.reload.possible_answers.first

        described_class.create!(submission: submission, question: question, possible_answer: possible_answer)

        error_message = /duplicate key value violates unique constraint "index_answers_on_sub_id_and_q_id_and_pa_id_and_null_text_answer"/
        expect do
          described_class.create!(submission: submission, question: question, possible_answer: possible_answer)
        end.to raise_error(ActiveRecord::StatementInvalid, error_message)
      end
    end

    context 'when both text_answer and possible_answer_id are nil' do
      it 'rolls back a CREATE statement' do
        expect do
          described_class.create!(text_answer: nil, possible_answer_id: nil, question: create(:question), submission: submission)
        end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint "answer_emptiness_check"/)
      end
    end
  end

  describe '#delete_outdated_automation_failure_tag' do
    let(:automation_failure_tag) { create(:tag, name: Tag::AUTOMATION_PLACEHOLDER_NAME) }
    let(:answer) { create(:answer) }

    it 'does not delete a tag that is the first tag on the answer and represents an automation failure' do
      expect(answer.reload.tags.count).to eq 0
      answer.tags << automation_failure_tag

      expect(answer.reload.tags.count).to eq 1
      expect(answer.tags.first.name).to eq Tag::AUTOMATION_PLACEHOLDER_NAME
    end

    it 'deletes the automation failure tag after a new tag gets assigned to an answer' do
      answer.tags << automation_failure_tag
      expect(answer.reload.tags.count).to eq 1
      expect(answer.tags.first.name).to eq Tag::AUTOMATION_PLACEHOLDER_NAME

      ordinary_tag = create(:tag)
      answer.tags << ordinary_tag
      expect(answer.reload.tags.count).to eq 1
      expect(answer.tags.first.name).to eq ordinary_tag.name
    end
  end

  describe "#answers_count" do
    let(:time_zone) { ActiveSupport::TimeZone['GMT'] }
    let(:possible_answer) { create(:possible_answer) }

    # Generate survey results matching for every possible combination of provided filters
    def generate_data(dates, devices, markets, urls)
      # [1, 2, 3]
      # ['a', 'b', 'c']
      # [:a, :b, :c]
      # [[1,'a',:a], [1, 'a', :b] ...]
      dates.product(devices).product(markets).product(urls).map(&:flatten).each do |date, device, market, url|
        survey = Survey.where(id: market).first || create(:survey, id: market)
        submission = create(:submission, device_type: device, survey_id: market, url: url)
        create(:answer, submission: submission, created_at: date, question: survey.questions.first)
      end
    end

    # 1 target, 3 ignored
    # We rely on 4, it simplifies the tests
    it "filters all combinations" do
      target_date = time_zone.parse("2021-01-13")
      ignored_dates = [time_zone.parse("2021-08-20"), time_zone.parse("2021-08-21"), time_zone.parse("2021-01-12")]
      dates = [target_date] + ignored_dates

      target_device = 'desktop'
      ignored_devices = %w(mobile tablet iphone)
      devices = [target_device] + ignored_devices

      target_market = 1
      ignored_markets = [2, 3, 4]
      markets = [target_market] + ignored_markets

      target_url = 'a'
      ignored_urls = %w(b c d)
      urls = [target_url] + ignored_urls

      generate_data(dates, devices, markets, urls)

      expect(Submission.count).to eq(dates.length * devices.length * markets.length * urls.length)
      expect(described_class.count).to eq(dates.length * devices.length * markets.length * urls.length)

      all_filters = {
        date_range: target_date,
        device_types: target_device,
        market_ids: target_market,
        completion_urls: [CompletionUrlFilter.new('contains', target_url, cumulative: false)]
      }

      all_filters.length.times do |i|
        all_filters.keys.combination(i + 1).each do |filter_key_combination|
          cur_filters = {}

          filter_key_combination.each do |filter|
            cur_filters[filter] = all_filters[filter]
          end

          answers_count = described_class.answers_count(described_class.all, filters: cur_filters)
          expect(answers_count).to eq(4 ** (all_filters.length - cur_filters.length))
        end
      end
    end

    it "can group answers to multiple choice questions" do
      survey = create(:survey_with_one_multiple_question)
      survey.reload
      question = survey.questions.first

      3.times do |_|
        submission = create(:submission)

        possible_answer = question.possible_answers.first
        create(:answer, submission: submission, question: question, possible_answer: possible_answer)

        possible_answer = question.possible_answers.last
        create(:answer, submission: submission, question: question, possible_answer: possible_answer)
      end

      answers_count = described_class.answers_count(described_class.all, ignore_multiple_type_dup: true)
      expect(answers_count).to eq(3)
    end

    def make_answer(submission_extras: {}, answer_extras: {})
      submission = create(:submission, **submission_extras)
      create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        scope = described_class.all

        filter_key = filters.keys.first
        scope = case filter_key
        when :date_range
          scope.where(created_at: filters[filter_key])
        when :device_types
          scope.joins(:submission).where(submissions: { device_type: filters[filter_key] })
        when :completion_urls
          scope.joins(:submission).where(CompletionUrlFilter.combined_sql(filters[filter_key]))
        when :possible_answer_id
          submission_ids = Answer.where(possible_answer_id: filters[filter_key]).pluck(:submission_id)
          scope.joins(:submission).where(submissions: { id: submission_ids })
        when :pageview_count, :visit_count
          scope.joins(:submission).where(filters[filter_key].to_sql)
        when nil
          scope
        else
          raise "Unrecognized filter #{filter_key}"
        end

        expect(described_class.answers_count(described_class.all, filters: filters)).to eq(
          scope.count
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
          make_possible_answer_filter_records(possible_answer.question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    it "can handle market (survey_id) filters" do
      base_survey = create(:localized_survey)

      survey_locale_group = base_survey.survey_locale_group
      duplicate_survey = base_survey.duplicate
      duplicate_survey.save
      duplicate_survey.add_to_localization_group(survey_locale_group.id, "en-ca")

      3.times do |_|
        submission = create(:submission, survey_id: base_survey.id)
        create(:answer, submission: submission, question: base_survey.questions.first)
      end

      submission = create(:submission, survey_id: duplicate_survey.id)
      create(:answer, submission: submission, question: duplicate_survey.questions.first)

      target_market = duplicate_survey.id

      answers_count = described_class.answers_count(described_class.all, filters: { market_ids: [duplicate_survey.id]})
      expect(answers_count).to eq(1)
    end
  end

  # magnitude (0, +inf)
  # score (-1, +1)
  describe "#human_friendly_sentiment" do
    subject { answer.human_friendly_sentiment }

    let(:score) { 0 }
    let(:magnitude) { 0 }
    let(:answer) { create(:answer, sentiment: { "score" => score, "magnitude" => magnitude }) }

    context "when magnitude >= 0.4" do
      let(:magnitude) { 0.4 }

      context "when score >= 0.5" do
        let(:score) { 0.5 }

        it { is_expected.to eq "Very Positive" }
      end

      context "when -0.5 < score < 0.5" do
        let(:score) { 0 }

        it { is_expected.to eq "Neutral" }
      end

      context "when score <= -0.5" do
        let(:score) { -0.5 }

        it { is_expected.to eq "Very Negative" }
      end
    end

    context "when magnitude < 0.4" do
      let(:magnitude) { 0.39 }

      context "when score >= 0.5" do
        let(:score) { 0.5 }

        it { is_expected.to eq "Positive" }
      end

      context "when -0.5 < score < 0.5" do
        let(:score) { 0 }

        it { is_expected.to eq "Neutral" }
      end

      context "when score <= -0.5" do
        let(:score) { -0.5 }

        it { is_expected.to eq "Negative" }
      end
    end
  end
end
