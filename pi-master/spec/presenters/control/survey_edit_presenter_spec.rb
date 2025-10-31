# frozen_string_literal: true
require 'spec_helper'

describe Control::SurveyEditPresenter do
  let(:account) { create(:account) }

  before do
    @survey = create(:survey, account: account)
    current_user = create(:user, account: account)
    open_tab_name = "General"

    @presenter = described_class.new(@survey, current_user, open_tab_name)
  end

  describe "question_data" do
    let(:question_datum_keys) do
      %i(
        id type position content customContent nextQuestionId
        nextQuestionColumn nextQuestionAllowed nps index randomize
        buttonType answersPerRowDesktop answersPerRowMobile singleChoiceDefaultLabel
        desktopWidthType answersAlignmentDesktop mobileWidthType answersAlignmentMobile
        beforeQuestionText afterQuestionText beforeAnswersCount afterAnswersCount
        beforeAnswersItems afterAnswersItems hintText submitLabel
        errorText height maxLength maximumSelection enableMaximumSelection
        emptyErrorText maximumSelectionsExceededErrorText fullscreen autocloseEnabled
        autocloseDelay autoredirectEnabled autoredirectDelay autoredirectUrl showAfterAAO
        opacity backgroundColor imageSettings diagramProperties sliderSubmitButtonEnabled
        showAdditionalContent additionalContent additionalContentPosition sliderStartPosition
        optional
      )
    end

    it "returns question data" do
      question_data = @presenter.question_data

      expect(question_data.length).to eq @survey.questions.count

      # TODO: Validate the schema in full with dry-rb
      question_data.each do |question_datum|
        expect(question_datum.keys).to contain_exactly(:questionData, :possibleAnswers)

        expect(question_datum[:questionData].keys).to match_array(question_datum_keys)
      end
    end
  end

  describe '#survey_tags' do
    let(:survey_tag) { create(:survey_tag, name: 'a', account: account) }

    before do
      @survey.survey_tags << survey_tag
      create(:survey_tag, name: 'b', account: account)
    end

    it 'returns the correct keys' do
      @presenter.survey_tags.each do |survey_tag|
        expect(survey_tag.keys).to match_array %i(value label)
        expect(survey_tag[:value].keys).to match_array %i(surveyTagId appliedSurveyTagId)
      end
    end

    it 'has appliedSurveyTagId entry filled if a survey tag is applied' do
      applied_survey_tag_ids = @presenter.survey_tags.map { |survey_tag| survey_tag[:value][:appliedSurveyTagId] }
      expect(applied_survey_tag_ids.compact).to match_array AppliedSurveyTag.where(survey: @survey, survey_tag: survey_tag).ids
    end

    it 'sorts entries alphabetically' do
      survey_tag_labels = @presenter.survey_tags.map { |survey_tag| survey_tag[:label] }
      expect(survey_tag_labels).to eq %w(a b)
    end
  end

  describe "#audit_log" do
    context "when the user has reporting only access" do
      before do
        current_user = create(:reporting_only_user)
        survey = create(:survey, account: current_user.account)
        open_tab_name = "General"

        @presenter = described_class.new(survey, current_user, open_tab_name)
      end

      it "returns an empty array" do
        expect(@presenter.audit_log).to be_empty
      end
    end
  end
end
