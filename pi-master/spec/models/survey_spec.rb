# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe Survey do
  let!(:survey_translation_changes) do
    described_class.translated_fields.each_with_object({}) do |field, memo|
      memo[field] = FFaker::Lorem.phrase
      memo
    end
  end

  let!(:question_translation_changes) do
    Question.translated_fields.each_with_object({}) do |field, memo|
      memo[field] = FFaker::Lorem.phrase
      memo
    end
  end

  let!(:possible_answer_translation_changes) do
    PossibleAnswer.translated_fields.each_with_object({}) do |field, memo|
      memo[field] = FFaker::Lorem.phrase
      memo
    end
  end

  it "is able to create a survey" do
    create(:survey)
    expect(described_class.count).to eq(1)
  end

  it 'creates a default url trigger' do
    expect { create(:survey, create_default_associations: true) }.to change { Trigger.count }.by(1)
  end

  describe "#duplicate" do
    let(:survey) { create(:survey) }

    context "when there are invitation diagram properties" do
      before do
        2.times do
          user = create(:user, account: survey.account)
          create(:invitation_diagram_properties, user_id: user.id, node_record_id: survey.id)
        end

        @duplicate_survey = survey.duplicate
        @duplicate_survey.save
      end

      it "duplicates the invitation diagram properties" do
        expect(@duplicate_survey.invitation_diagram_properties.count).to eq survey.invitation_diagram_properties.count

        survey.invitation_diagram_properties.each do |diagram_property|
          expect(
            @duplicate_survey.invitation_diagram_properties.where(
              node_type: diagram_property.node_type,
              position: diagram_property.position,
              user_id: diagram_property.user_id
            ).exists?
          ).to be true
        end
      end
    end

    context "when there are thank you diagram properties" do
      before do
        2.times do
          user = create(:user, account: survey.account)
          create(:thank_you_diagram_properties, user_id: user.id, node_record_id: survey.id)
        end

        @duplicate_survey = survey.duplicate
        @duplicate_survey.save
      end

      it "duplicates the thank you diagram properties" do
        expect(@duplicate_survey.thank_you_diagram_properties.count).to eq survey.thank_you_diagram_properties.count

        survey.thank_you_diagram_properties.each do |diagram_property|
          expect(
            @duplicate_survey.thank_you_diagram_properties.where(
              node_type: diagram_property.node_type,
              position: diagram_property.position,
              user_id: diagram_property.user_id
            ).exists?
          ).to be true
        end
      end
    end

    context "when its questions have diagram properties" do
      before do
        2.times do
          user = create(:user, account: survey.account)
          question = create(:question, survey: survey)

          create(:question_diagram_properties, user_id: user.id, node_record_id: question.id)
        end

        @duplicate_survey = survey.duplicate
        @duplicate_survey.save
      end

      it "duplicates the question's diagram properties" do
        survey.questions.each_with_index do |question, question_index|
          duplicate_question = @duplicate_survey.questions[question_index]

          expect(question.diagram_properties.count).to eq(duplicate_question.diagram_properties.count)

          question.diagram_properties.each do |diagram_property|
            expect(
              duplicate_question.diagram_properties.where(
                node_type: diagram_property.node_type,
                position: diagram_property.position,
                user_id: diagram_property.user_id
              ).exists?
            ).to be true
          end
        end
      end
    end
  end

  describe "#updated_by_name" do
    let(:survey) { create(:survey) }
    let(:first_editor) { create(:user) }
    let(:last_editor) { create(:user) }

    it "returns the name of the user who last modified it" do
      Audited.audit_class.as_user(first_editor) do
        survey.update(name: FFaker::Lorem.phrase)
      end

      Audited.audit_class.as_user(last_editor) do
        survey.update(name: FFaker::Lorem.phrase)
      end

      expect(survey.updated_by_name).to eq(last_editor.name)
    end

    it "returns the name of the last existing user to modify it" do
      Audited.audit_class.as_user(first_editor) do
        survey.update(name: FFaker::Lorem.phrase)
      end

      Audited.audit_class.as_user(last_editor) do
        survey.update(name: FFaker::Lorem.phrase)
      end

      last_editor.destroy

      expect(survey.updated_by_name).to eq(first_editor.name)
    end

    it "returns a placeholder if no user can be found" do
      expect(survey.updated_by_name).to eq("unavailable")
    end
  end

  describe '#attributes_for_javascript' do
    it 'contains theme_css if present' do
      survey = create(:survey)
      theme = create(:theme, name: 'custom theme')
      survey.update(theme: theme)

      expect(survey.attributes_for_javascript[:theme_css]).to eq theme.css
    end
  end

  describe '#first_ever_launch_date' do
    context 'when the survey was live at its creation' do
      it 'returns the value from "create" type audits' do
        survey = create(:survey, status: :live)
        survey.update(status: :draft)
        survey.update(status: :live)
        survey.update(status: :paused)

        expect(survey.first_ever_launch_date).to eq survey.audits.where(action: 'create').first.audited_changes['live_at']
      end
    end

    context 'when the survey was later turned to live' do
      it 'returns the value from "update" type audits' do
        survey = create(:survey, status: :draft)
        survey.update(status: :live)
        survey.update(status: :paused)
        survey.update(status: :live)

        expect(survey.first_ever_launch_date).to eq survey.audits.where(action: 'update').first.audited_changes['live_at'].last
      end
    end

    context 'when the survey has never been set to live' do
      it 'returns nil' do
        survey = create(:survey, status: :draft)
        survey.update(status: :paused)
        expect(survey.first_ever_launch_date).to be_nil
      end
    end
  end

  describe "#survey_tag_names" do
    subject { survey.applied_survey_tag_names }

    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }

    before do
      create(:survey_tag, account: account)
    end

    context 'when no tag is applied' do
      it { is_expected.to eq '' }
    end

    context 'when some tags are applied' do
      let(:survey_tag_name) { FFaker::Lorem.unique.word }
      let(:survey_tag_name2) { FFaker::Lorem.unique.word }

      before do
        survey.survey_tags << create(:survey_tag, name: survey_tag_name, account: account)
        survey.survey_tags << create(:survey_tag, name: survey_tag_name2, account: account)
      end

      it { is_expected.to eq [survey_tag_name, survey_tag_name2].join(',') }
    end
  end

  describe "validations" do
    it "converts blank language codes to null" do
      survey = create(:survey)
      survey.reload

      expect(survey.language_code).to be_nil

      survey.update(language_code: " ")
      survey.reload

      expect(survey.language_code).to be_nil
    end

    # unique, no gaps, 0-based
    it "is invalid if its questions are not in the proper order" do
      survey = create(:survey_without_question)
      expect(survey.valid?).to be true

      create(:question, survey: survey, position: -1)
      survey.reload
      expect(survey.valid?).to be false
      Question.destroy_all

      create(:question, survey: survey, position: 1)
      survey.reload
      expect(survey.valid?).to be false
      Question.destroy_all

      create(:question, survey: survey, position: 0)
      create(:question, survey: survey, position: 0)
      survey.reload
      expect(survey.valid?).to be false
      Question.destroy_all

      create(:question, survey: survey, position: 0)
      create(:question, survey: survey, position: 2)
      survey.reload
      expect(survey.valid?).to be false
    end

    # unique, no gaps, 0-based
    it "is valid if its questions are in the proper order" do
      survey = create(:survey_without_question)
      expect(survey.valid?).to be true

      create(:question, survey: survey, position: 0)
      create(:question, survey: survey, position: 1)
      create(:question, survey: survey, position: 2)
      survey.reload
      expect(survey.valid?).to be true
    end

    it 'ensures colors are in the RGB format' do
      survey = create(:survey)

      good_values = %w(#000 #ffffff #BBB)
      good_values.each do |good_value|
        survey.text_color = good_value
        expect(survey.valid?).to be true
      end
      bad_values = %w(000 #fffffff #xyz)
      bad_values.each do |bad_value|
        survey.text_color = bad_value
        expect(survey.valid?).to be false
      end
    end
  end

  def make_impression(extras = {})
    create(:submission, survey: survey, **extras)
  end

  def make_impression_records(filter_attribute = nil, attribute_value = nil)
    make_impression and return if filter_attribute.nil?

    case filter_attribute
    when :created_at, :device_type, :url, :pageview_count, :visit_count
      make_impression({ filter_attribute => attribute_value })
    when :possible_answer_id
      make_possible_answer_filter_records(survey, attribute_value)
    else
      raise "Unrecognized data type #{filter_attribute}"
    end
  end

  describe '#submission_rate' do
    let(:viewed_impressions_enabled_at) { FFaker::Time.datetime }

    let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }
    let(:survey) { create(:survey, account: account) }

    # Viewed impressions are utilized the day after it was enabled
    let(:start_at) { account.viewed_impressions_calculation_start_at }

    before do
      create_list(:submission, 5, survey: survey, created_at: viewed_impressions_enabled_at)
      create_list(:submission, 5, survey: survey, created_at: viewed_impressions_enabled_at, viewed_at: FFaker::Time.datetime)
      create_list(:submission, 5, survey: survey, created_at: start_at)
      create_list(:submission, 5, survey: survey, created_at: start_at, viewed_at: FFaker::Time.datetime)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filter)
        expected_impressions_count = survey.impressions_count(filters: filter).to_f
        expected_rate = expected_impressions_count.zero? ? 0 : survey.submissions_count(filters: filter) / expected_impressions_count

        expect(survey.submission_rate(filters: filter)).to eq(
          expected_rate
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_impression_records(filter_attribute, attribute_value)
      end
    end

    context 'when the denominator is zero' do
      before do
        Submission.delete_all
      end

      it "returns 0" do
        expect(survey.submission_rate(filters: {})).to eq 0
      end
    end

    context 'when the denominator is not zero' do
      before do
        allow(survey).to receive_messages(blended_impressions_count: 3, submissions_count: 1)
      end

      it 'rounds a number to 2 decimal places' do
        expect(survey.submission_rate(filters: {}).to_s).to match(/\d+\.\d{2}\z/)
      end
    end
  end

  describe "#impressions_count" do
    it_behaves_like "filter sharing" do
      let(:survey) { create(:survey) }
      let(:question) { survey.questions.first }
      let(:possible_answer) { question.possible_answers.first }

      def it_filters(filters)
        scope = survey.impressions
        scope = Submission.filtered_submissions(scope, filters: filters)

        expect(survey.impressions_count(filters: filters)).to eq(
          scope.count
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_impression_records(filter_attribute, attribute_value)
      end
    end
  end

  describe "#viewed_impressions_count" do
    def make_viewed_impression(extras = {})
      create(:submission, survey: survey, **extras, created_at: viewed_impressions_enabled_at, viewed_at: viewed_impressions_enabled_at)
    end

    it_behaves_like "filter sharing" do
      let(:viewed_impressions_enabled_at) { FFaker::Time.between(Time.new(2014, 10), Time.current) }
      let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }

      let(:survey) { create(:survey, account: account) }
      let(:question) { survey.questions.first }
      let(:possible_answer) { question.possible_answers.first }

      def it_filters(filters)
        scope = survey.viewed_impressions
        scope = Submission.filtered_submissions(scope, filters: filters)

        expect(survey.viewed_impressions_count(filters: filters)).to eq(
          scope.count
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_viewed_impression and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_viewed_impression({ filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    context 'when date_range is not specified' do
      let(:viewed_impressions_enabled_at) { FFaker::Time.datetime }

      let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }
      let(:survey) { create(:survey, account: account) }

      before do
        travel_to viewed_impressions_enabled_at

        3.times { create(:submission, survey: survey, viewed_at: Time.current) }
      end

      it 'starts date_range from when viewed impressions was turned on' do
        filters = { date_range: viewed_impressions_enabled_at..10.hours.after }
        expect(Submission).to receive(:filtered_submissions).with(survey.viewed_impressions, filters: filters).and_call_original

        survey.viewed_impressions_count

        travel_back
      end
    end
  end

  describe "#submissions_count" do
    let(:survey) { create(:survey) }
    let(:question) { survey.questions.first }
    let(:possible_answer) { question.possible_answers.first }

    def make_submission(extras = {})
      submission = create(:submission, survey: survey, **extras)
      create(:answer, submission: submission, possible_answer: possible_answer)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        scope = survey.submissions
        scope = Submission.filtered_submissions(scope, filters: filters)

        expect(survey.submissions_count(filters: filters)).to eq(
          scope.count
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_submission and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_submission({ filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end

  describe "#blended_impressions_count" do
    let(:viewed_impressions_enabled_at) { FFaker::Time.datetime }

    let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }
    let(:survey) { create(:survey, account: account) }
    let(:question) { survey.questions.first }
    let(:possible_answer) { question.possible_answers.first }

    def make_submissions(extras = {})
      # observer hasn't been enabled yet
      create(:submission, survey: survey, created_at: viewed_impressions_enabled_at - 1.day, **extras)

      # observer has been enabled for more than a day
      create(:submission, survey: survey, viewed_at: nil, created_at: viewed_impressions_enabled_at + 2.days, **extras)
      create(:submission, survey: survey, viewed_at: FFaker::Time.datetime, created_at: viewed_impressions_enabled_at + 2.days, **extras)

      # observer has been enabled for less than a day
      create(:submission, survey: survey, created_at: viewed_impressions_enabled_at + 0.5.day, **extras)
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

      expect(survey.blended_impressions_count(filters: filters)).to eq num_impressions
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        scope = survey.impressions
        scope = Submission.filtered_submissions(scope, filters: filters)

        it_calculates_accurate_blended_impressions(scope, filters)
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_submissions and return if filter_attribute.nil?

        case filter_attribute
        when :created_at, :device_type, :url, :pageview_count, :visit_count
          make_submissions({ filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    describe 'date_range' do
      let(:viewed_impressions_enabled_at) { FFaker::Time.datetime }

      let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }
      let(:survey) { create(:survey, account: account) }

      # Viewed impressions are utilized the day after it was enabled
      let(:start_at) { account.viewed_impressions_calculation_start_at }

      let(:impression_count_before_enabled_at) { rand(10) }
      let(:impression_count_between_enabled_at_and_start_at) { rand(10) }
      let(:impression_count_at_start_at) { rand(10) }
      let(:impression_count_after_start_at) { rand(10) }

      let(:viewed_impression_count_between_enabled_at_and_start_at) { rand(10) }
      let(:viewed_impression_count_at_start_at) { rand(10) }
      let(:viewed_impression_count_after_start_at) { rand(10) }

      before do
        impression_count_before_enabled_at.times do
          create(:submission, survey: survey, created_at: viewed_impressions_enabled_at - 1.day)
        end
        impression_count_between_enabled_at_and_start_at.times do
          create(:submission, survey: survey, created_at: start_at - 1.day)
        end
        impression_count_at_start_at.times do
          create(:submission, survey: survey, created_at: start_at)
        end
        impression_count_after_start_at.times do
          create(:submission, survey: survey, created_at: start_at + 1.day)
        end

        viewed_impression_count_between_enabled_at_and_start_at.times do
          create(:submission, survey: survey, viewed_at: FFaker::Time.datetime, created_at: start_at - 1.day)
        end
        viewed_impression_count_at_start_at.times do
          create(:submission, survey: survey, viewed_at: FFaker::Time.datetime, created_at: start_at)
        end
        viewed_impression_count_after_start_at.times do
          create(:submission, survey: survey, viewed_at: FFaker::Time.datetime, created_at: start_at + 1.day)
        end
      end

      context 'when date_range is not specified' do
        let(:date_range) { nil }

        it 'counts served impressions made before start_at and viewed impressions made after start_at' do
          blended_impression_count =
            impression_count_before_enabled_at +
            impression_count_between_enabled_at_and_start_at +
            viewed_impression_count_between_enabled_at_and_start_at +
            viewed_impression_count_at_start_at +
            viewed_impression_count_after_start_at

          expect(survey.blended_impressions_count(filters: { date_range: date_range })).to eq blended_impression_count
        end
      end

      context 'when start_at is before date_range' do
        let(:date_range) { (start_at + 1.day)...(start_at + 10.days) }

        it 'only counts viewed impressions' do
          expect(survey.blended_impressions_count(filters: { date_range: date_range })).to eq viewed_impression_count_after_start_at
        end
      end

      context 'when start_at is in date_range' do
        let(:date_range) { (start_at - 1.day)..(start_at + 1.day) }

        it 'counts served impressions made before start_at and viewed impressions made after start_at' do
          blended_impression_count =
            impression_count_between_enabled_at_and_start_at +
            viewed_impression_count_between_enabled_at_and_start_at +
            viewed_impression_count_at_start_at +
            viewed_impression_count_after_start_at

          expect(survey.blended_impressions_count(filters: { date_range: date_range })).to eq blended_impression_count
        end
      end

      context 'when start_at is after date_range' do
        let(:date_range) { (start_at - 10.days)...(start_at - 1.day) }

        it 'only counts viewed impressions' do
          expect(survey.blended_impressions_count(filters: { date_range: date_range })).to eq impression_count_before_enabled_at
        end
      end
    end
  end

  describe 'human_submission_rate' do
    let(:account) { create(:account, viewed_impressions_enabled_at: FFaker::Time.datetime) }
    let(:survey) { create(:survey, account: account) }

    before do
      create(:submission, survey: survey, device_type: 'desktop', answers_count: 1)
      create(:submission, survey: survey, device_type: 'desktop')
      create(:submission, survey: survey, device_type: 'mobile', answers_count: 1)
      create(:submission, survey: survey, device_type: 'email')
    end

    it 'calculates human_submission_rate based only on submissions made with the specified device' do
      ['desktop', 'mobile', 'email', %w(desktop mobile), %w(mobile email), []].each do |device_type|
        filter = {device_types: device_type}
        submission_rate = survey.submission_rate(filters: filter)

        expect(survey.human_submission_rate(filters: filter)).to eq("#{(submission_rate * 100).to_i}%")
      end

      expect(survey.human_submission_rate(filters: {})).to eq("#{(survey.submission_rate(filters: {}) * 100).to_i}%")
    end
  end

  describe 'cached stats' do
    let(:date_range) { 3.days.ago.to_date..Date.today }

    let(:account) { create(:account, viewed_impressions_enabled_at: FFaker::Time.between(date_range.first, date_range.last)) }
    let(:survey) { create(:survey, account: account) }

    before do
      create(:survey_submission_cache, survey: survey, applies_to_date: date_range.first - 1.day)
      @caches = date_range.map { |date| create(:survey_submission_cache, survey: survey, applies_to_date: date) }
      create(:survey_submission_cache, survey: survey, applies_to_date: date_range.last + 1.day)
    end

    describe '#cached_impressions_count' do
      it 'sums the cache records applied during the specified date range' do
        expect(survey.cached_impressions_count(date_range)).to eq @caches.sum(&:impression_count)
      end
    end

    describe '#cached_viewed_impressions_count' do
      it 'sums the cache records applied during the specified date range' do
        expect(survey.cached_viewed_impressions_count(date_range)).to eq @caches.sum(&:viewed_impression_count)
      end
    end

    describe '#cached_submissions_count' do
      it 'sums the cache records applied during the specified date range' do
        expect(survey.cached_submissions_count(date_range)).to eq @caches.sum(&:submission_count)
      end
    end

    describe '#cached_submission_rate' do
      it 'calculates a rate by blending impressions and viewed impression as the denominator' do
        start_at = account.viewed_impressions_calculation_start_at
        blended_impression_count = @caches.sum { |cache| cache.applies_to_date >= start_at ? cache.viewed_impression_count : cache.impression_count }
        expect(survey.cached_submission_rate(date_range)).to eq (@caches.sum(&:submission_count).to_f/blended_impression_count).round(2)
      end
    end
  end

  describe "being localized" do
    it "can be localized" do
      account = create(:account)
      base_survey = create(:survey)
      base_survey.reload

      expect(SurveyLocaleGroup.count).to eq(0)
      expect(QuestionLocaleGroup.count).to eq(0)
      expect(PossibleAnswerLocaleGroup.count).to eq(0)

      base_survey.localize!

      expect(SurveyLocaleGroup.count).to eq(1)
      expect(QuestionLocaleGroup.count).to eq(base_survey.questions.count)
      expect(PossibleAnswerLocaleGroup.count).to eq(base_survey.possible_answers.count)

      survey_locale_group = SurveyLocaleGroup.first
      expect(base_survey.survey_locale_group_id).to eq(survey_locale_group.id)

      question_locale_groups = survey_locale_group.question_locale_groups.order(:created_at)

      base_survey.questions.each_with_index do |question, question_index|
        question_locale_group = question_locale_groups[question_index]
        expect(question.question_locale_group_id).to eq(question_locale_group.id)

        possible_answer_locale_groups = question_locale_group.possible_answer_locale_groups.order(:created_at)
        expect(possible_answer_locale_groups.pluck(:id)).to match_array(question.possible_answers.pluck(:possible_answer_locale_group_id))
      end
    end

    it "generates unique default names for its QuestionLocaleGroups" do
      base_survey = create(:survey_without_question)

      create(:question, survey_id: base_survey.id, content: "What is your name?")
      create(:question, survey_id: base_survey.id, content: "What is your name?")
      create(:question, survey_id: base_survey.id, content: "What is your name?")
      create(:question, survey_id: base_survey.id, content: "How are you?")

      base_survey.localize!

      expect(SurveyLocaleGroup.first.question_locale_groups.count).to eq(Question.count)
      expect(QuestionLocaleGroup.order(:created_at).pluck(:name).uniq.count).to eq(Question.count)
    end

    it "generates unique default names for its PossibleAnswerLocaleGroups" do
      account = create(:account)
      base_survey = create(:survey_with_one_question, account: account)
      base_survey.reload
      base_survey.questions.first.possible_answers.destroy_all

      create(:possible_answer, question_id: base_survey.questions.first.id, content: "Ekohe")
      create(:possible_answer, question_id: base_survey.questions.first.id, content: "Ekohe")
      create(:possible_answer, question_id: base_survey.questions.first.id, content: "Ekohe")
      create(:possible_answer, question_id: base_survey.questions.first.id, content: "Jonathan")

      base_survey.localize!

      expect(QuestionLocaleGroup.first.possible_answer_locale_groups.count).to eq(PossibleAnswer.count)
      expect(PossibleAnswerLocaleGroup.order(:created_at).pluck(:name).uniq.count).to eq(PossibleAnswerLocaleGroup.count)
    end

    it "has all of its fields translated" do
      base_survey = create(:survey)
      base_survey.reload

      configure_stubs

      base_survey.update(translation_changes(base_survey))

      expect(LocaleTranslationCache.count).to be(0)
      base_survey.localize!
      expect_cache_records

      expect_translations(base_survey)
    end
  end

  describe "being added to a localization group" do
    before do
      @base_survey = create(:survey, language_code: 'en_us')
      @base_survey.reload
      @language_code = "en_ca"
    end

    it "is added in the best-case scenario" do
      new_survey = @base_survey.duplicate
      new_survey.save
      expect(new_survey.language_code).to be_nil

      @base_survey.localize!

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be true

      new_survey.reload

      expect(new_survey.survey_locale_group_id).to eq @base_survey.survey_locale_group_id

      @base_survey.questions.includes(:possible_answers).each_with_index do |base_question, question_index|
        expect(new_survey.questions[question_index].question_locale_group_id).to eq base_question.question_locale_group_id

        base_question.possible_answers.each_with_index do |base_possible_answer, possible_answer_index|
          possible_answer = new_survey.questions[question_index].possible_answers[possible_answer_index]
          expect(possible_answer.possible_answer_locale_group_id).to eq base_possible_answer.possible_answer_locale_group_id
        end
      end

      expect(new_survey.language_code).to eq @language_code
    end

    it "cannot be done if the survey already belongs to a group" do
      new_survey = @base_survey.duplicate
      new_survey.save

      @base_survey.localize!

      new_survey.update(survey_locale_group_id: LocaleGroup.order(:id).last.id + 1)

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the question count is different from the base's" do
      new_survey = @base_survey.duplicate
      new_survey.save
      create(:question, survey: new_survey)
      new_survey.reload

      @base_survey.localize!

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the possible answer count for each question is different from the base's" do
      new_survey = @base_survey.duplicate
      new_survey.save

      # more questions than base
      create(:possible_answer, content: 'new possible answer', question: new_survey.questions.last)

      new_survey.reload

      @base_survey.localize!

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false

      # fewer questions than base
      new_survey.possible_answers.last(2).each(&:destroy)

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the question routing is different from the base's" do
      create(:question, survey: @base_survey)

      expect(@base_survey.questions.count).to eq 3
      @base_survey.questions.first.update(next_question_id: @base_survey.questions.last.id)

      new_survey = @base_survey.duplicate
      new_survey.save

      new_survey.questions.first.update(next_question_id: new_survey.questions[1].id)

      @base_survey.localize!

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the base survey belongs to a different account" do
      new_survey = @base_survey.duplicate
      new_survey.account = create(:account)
      new_survey.save

      @base_survey.localize!

      result = new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the survey locale group does not exist" do
      new_survey = @base_survey.duplicate
      new_survey.save

      result = new_survey.add_to_localization_group(-1, @language_code)
      expect(result).to be false
    end

    it "cannot be done if the base survey does not exist" do
      new_survey = @base_survey.duplicate
      new_survey.save

      survey_locale_group = SurveyLocaleGroup.create(name: "test")

      result = new_survey.add_to_localization_group(survey_locale_group.id, @language_code)
      expect(result).to be false
    end

    it "has all of its fields translated" do
      configure_stubs

      @base_survey.update(translation_changes(@base_survey))

      new_survey = @base_survey.duplicate
      new_survey.save

      @base_survey.localize!

      new_survey.add_to_localization_group(@base_survey.survey_locale_group_id, @language_code)
      new_survey.reload
      expect_cache_records

      expect_translations(new_survey)
    end
  end

  describe "a localized survey" do
    before do
      @base_survey = create(:localized_survey)
    end

    it "cannot be localized a second time" do
      old_survey_locale_group_count = SurveyLocaleGroup.count
      old_question_locale_group_count = QuestionLocaleGroup.count
      old_possible_answer_locale_group_count = PossibleAnswerLocaleGroup.count

      @base_survey.reload
      @base_survey.localize!

      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)
    end

    it "has its fields translated on update" do
      configure_stubs

      @base_survey.update(translation_changes(@base_survey))

      expect_cache_records

      expect_translations(@base_survey)
    end

    it "has its cache records' expected_language_code updated" do
      configure_stubs

      @base_survey.update(translation_changes(@base_survey))
      expect_cache_records

      new_language_code = "fr"
      @base_survey.update(translation_changes(@base_survey).merge(language_code: new_language_code))
      expect_cache_records

      expect(LocaleTranslationCache.pluck(:expected_language_code).uniq).to eq([new_language_code])
    end

    describe "which is not the base survey" do
      before do
        @survey = @base_survey.duplicate
        @survey.save
      end

      it "has its LocaleGroup references nulled out when it is destroyed" do
        survey_id = @survey.id
        @survey.destroy

        Question.where(survey_id: survey_id).each do |question|
          expect(question.question_locale_group_id).to be_nil

          question.possible_answers.each do |possible_answer|
            expect(possible_answer.possible_answer_locale_group_id).to be_nil
          end
        end
      end

      it "does not affect existing LocaleGroup records when it is destroyed" do
        old_survey_locale_group_count = SurveyLocaleGroup.count
        old_question_locale_group_count = QuestionLocaleGroup.count
        old_possible_answer_locale_group_count = PossibleAnswerLocaleGroup.count

        @survey.destroy

        expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
        expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)
        expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)
      end
    end
  end

  describe "unlocalize!" do
    before do
      survey.unlocalize!
      survey.questions.reload
      survey.possible_answers.reload
    end

    context "with a localized survey" do
      let(:survey) { create(:localized_survey) }

      it "is no longer localized" do
        expect(survey.localized?).to be false
      end

      it "removes all locale_group references" do
        expect(survey.survey_locale_group_id).to be_nil

        survey.questions.each do |question|
          expect(question.question_locale_group_id).to be_nil
        end

        survey.possible_answers.each do |possible_answer|
          expect(possible_answer.possible_answer_locale_group_id).to be_nil
        end
      end

      it "removes all translation cache records" do
        expect(survey.locale_translation_caches).to be_empty

        survey.questions.each do |question|
          expect(question.locale_translation_caches).to be_empty
        end

        survey.possible_answers.each do |possible_answer|
          expect(possible_answer.locale_translation_caches).to be_empty
        end
      end
    end

    # what exactly is this testing?
    context "with a non-localized survey" do
      let(:survey) { create(:survey) }

      it "doesn't explode, I guess" do
        expect(survey.localized?).to be false
      end
    end
  end

  describe "callbacks" do
    it_behaves_like 'Qrvey Synchronization callbacks' do
      def trigger_record
        @trigger_record ||= create(:survey_without_question)
      end
    end

    describe "destroying empty survey local group" do
      subject { SurveyLocaleGroup.count }

      context "when survey has a group" do
        let!(:survey_locale_group) { create(:survey_locale_group) }
        let!(:survey) { create(:survey, survey_locale_group: survey_locale_group) }

        context "when survey locale group is empty" do
          before do
            survey.destroy
          end

          it { is_expected.to eq 0 }
        end

        context "when survey locale group isn't empty" do
          before do
            survey_locale_group.surveys << create(:survey)
            survey.destroy
          end

          it { is_expected.to eq 1 }
        end
      end

      context "when survey has no groups" do
        let!(:survey) { create(:survey) }

        before do
          survey.destroy
        end

        it { is_expected.to eq 0 }
      end
    end
  end

  describe "#goal_reached?" do
    subject { survey.goal_reached? }

    let(:survey) { create(:survey) }

    context "when survey_stat.answers_count is greater than goal" do
      before do
        create(:survey_stat, survey: survey, answers_count: survey[:goal] + 1)
      end

      it { is_expected.to be true }
    end

    context "when survey_stat.answers_count is less than goal" do
      before do
        create(:survey_stat, survey: survey, answers_count: survey[:goal] - 1)
      end

      it { is_expected.to be false }
    end
  end

  describe "frequency_cap_active?" do
    subject { survey.frequency_cap_active? }

    let(:survey) { create(:survey) }

    context "when the survey's frequency cap is disabled" do
      before do
        survey.ignore_frequency_cap = true
      end

      it { is_expected.to be false }
    end

    context "when the account's frequency cap is enabled" do
      before do
        survey.account.update(frequency_cap_enabled: true)
      end

      it { is_expected.to be true }
    end

    context "when the survey's frequency cap is enabled and the account's frequency cap is disabled" do
      before do
        survey.account.update(frequency_cap_enabled: false)
        survey.update(ignore_frequency_cap: true)
      end

      it { is_expected.to be false }
    end
  end

  describe "#summarize" do
    subject { survey.summarize }

    context "when android_enabled is true" do
      let(:survey) { create(:survey, android_enabled: true) }

      it { is_expected.to include("When the device is an Android") }
    end

    context "when desktop_enabled is true" do
      let(:survey) { create(:survey, desktop_enabled: true) }

      it { is_expected.to include("When the device is a desktop") }
    end

    context "when ios_enabled is true" do
      let(:survey) { create(:survey, ios_enabled: true) }

      it { is_expected.to include("When the device is an iPhone") }
    end

    context "when email_enabled is true" do
      let(:survey) { create(:survey, email_enabled: true) }

      it { is_expected.to include("When the device is an e-mail client") }
    end

    context "when tablet_enabled is true" do
      let(:survey) { create(:survey, tablet_enabled: true) }

      it { is_expected.to include("When the device is a tablet") }
    end

    context "when sample_rate is set" do
      let(:survey) { create(:survey, sample_rate: 50) }

      it { is_expected.to include("With a sample rate of 50%") }
    end

    context "when refire_enabled is true" do
      let(:survey) { create(:survey, refire_enabled: true, refire_time: 10, refire_time_period: "minutes") }

      it { is_expected.to include("With a refire time of 10 minutes") }
    end

    context "when starts_at is configured" do
      let(:survey) { create(:survey, starts_at: 1.day.ago) }

      it { is_expected.to include("With a start date of #{survey.starts_at.strftime("%m/%d/%Y")}") }
    end

    context "when ends_at is configured" do
      let(:survey) { create(:survey, ends_at: 1.day.from_now) }

      it { is_expected.to include("With an end date of #{survey.ends_at.strftime("%m/%d/%Y")}") }
    end

    context "when stop_showing_without_answer is false" do
      let(:survey) { create(:survey, stop_showing_without_answer: false) }

      it { is_expected.not_to include("Will show the survey again even if the user has closed it once before.") }
    end

    context "when stop_showing_without_answer is true" do
      let(:survey) { create(:survey, stop_showing_without_answer: true) }

      it { is_expected.to include("Will stop showing if the user has closed the survey without answering it.") }
    end

    context "when ignore_frequency_cap is true" do
      let(:survey) { create(:survey, ignore_frequency_cap: true) }

      it { is_expected.to include("Will ignore frequency limits, showing the survey every time.") }
    end
  end

  def configure_stubs
    dummy_translation = {
      translated_text: FFaker::Lorem.phrase,
      detected_language_code: "en_ca"
    }

    allow(Survey).to receive(:fetch_translation_from_google) { |_method| dummy_translation }
    allow(Question).to receive(:fetch_translation_from_google) { |_method| dummy_translation }
    allow(PossibleAnswer).to receive(:fetch_translation_from_google) { |_method| dummy_translation }
  end

  def translation_changes(survey)
    changes_to_apply = survey_translation_changes
    changes_to_apply[:questions_attributes] = []

    survey.questions.each do |question|
      question_attributes = question_translation_changes.merge(id: question.id)
      question_attributes[:possible_answers_attributes] = []

      question.possible_answers.each do |possible_answer|
        question_attributes[:possible_answers_attributes] << possible_answer_translation_changes.merge(id: possible_answer.id)
      end

      changes_to_apply[:questions_attributes] << question_attributes
    end

    changes_to_apply
  end

  def expect_cache_records
    expected_num_survey_records = described_class.translated_fields.count * described_class.count
    expect(LocaleTranslationCache.where(record_type: "Survey").count).to eq(expected_num_survey_records)

    expected_num_question_records = Question.translated_fields.count * Question.count
    expect(LocaleTranslationCache.where(record_type: "Question").count).to eq(expected_num_question_records)

    expected_num_possible_answer_records = PossibleAnswer.translated_fields.count * PossibleAnswer.count
    expect(LocaleTranslationCache.where(record_type: "PossibleAnswer").count).to eq(expected_num_possible_answer_records)

    expect(LocaleTranslationCache.count).to eq(expected_num_survey_records + expected_num_question_records + expected_num_possible_answer_records)
  end

  def expect_translations(survey)
    expect_survey_fields_to_be_translated(survey)
    expect_question_fields_to_be_translated(survey)
    expect_possible_answer_fields_to_be_translated(survey)
  end

  def expect_survey_fields_to_be_translated(survey)
    described_class.translated_fields.each do |translated_field|
      cache_record = LocaleTranslationCache.find_by(record_id: survey.id, record_type: "Survey", column: translated_field)
      expect(cache_record).not_to be_nil, "expected to find cache record for #{translated_field}, got nothing"
      expect(cache_record.original).to eq survey_translation_changes[translated_field]
    end
  end

  def expect_question_fields_to_be_translated(survey)
    survey.questions.each do |question|
      Question.translated_fields.each do |translated_field|
        cache_record = LocaleTranslationCache.find_by(record_id: question.id, record_type: "Question", column: translated_field)
        expect(cache_record).not_to be_nil, "expected to find cache record for #{translated_field}, got nothing"
        expect(cache_record.original).to eq question_translation_changes[translated_field]
      end
    end
  end

  def expect_possible_answer_fields_to_be_translated(survey)
    survey.possible_answers.each do |possible_answer|
      PossibleAnswer.translated_fields.each do |translated_field|
        cache_record = LocaleTranslationCache.find_by(record_id: possible_answer.id, record_type: "PossibleAnswer", column: translated_field)
        expect(cache_record).not_to be_nil, "expected to find cache record for #{translated_field}, got nothing"
        expect(cache_record.original).to eq possible_answer_translation_changes[translated_field]
      end
    end
  end
end
