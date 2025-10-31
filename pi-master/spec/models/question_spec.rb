# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe Question do
  before do
    Survey.delete_all
    described_class.delete_all
    Answer.delete_all
    Submission.delete_all
    PossibleAnswer.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  describe "validations" do
    it_behaves_like "color validation" do
      subject { create(:question) }

      let(:attribute_to_validate) { :background_color }
    end

    it "is able to create a question" do
      question = create(:question_without_possible_answers, survey: create(:survey_without_question))

      expect(question.valid?).to be true
      expect(described_class.count).to eq(1)
    end

    it "cannot link to itself" do
      question = create(:question_without_possible_answers, survey: create(:survey_without_question))

      question.next_question_id = question.id

      expect(question.valid?).to be false
      expect(question.errors[:next_question_id].present?).to be true

      question.free_text_next_question_id = question.id
      expect(question.valid?).to be false
      expect(question.errors[:free_text_next_question_id].present?).to be true
    end
  end

  describe "Single choice question" do
    let(:question) { create(:single_choice_question) }

    it "has a default answers_per_row_desktop value" do
      expect(question.answers_per_row_desktop).to eq 3
    end

    it "has a default answers_per_row_mobile value" do
      expect(question.answers_per_row_mobile).to eq 3
    end
  end

  describe "Multiple choice question" do
    let(:question) { create(:multiple_choices_question) }

    it "has a default answers_per_row_desktop value" do
      expect(question.answers_per_row_desktop).to eq 3
    end

    it "has a default answers_per_row_mobile value" do
      expect(question.answers_per_row_mobile).to eq 3
    end

    it "can have randomize specified" do
      question.randomize = described_class::RANDOMIZE_ALL_EXCEPT_LAST

      expect(question.valid?).to be true
    end
  end

  describe "NPS question" do
    let(:question) { create(:nps_question) }

    it "has a default answers_per_row_desktop value" do
      expect(question.answers_per_row_desktop).to eq 11
    end

    it "has a default answers_per_row_mobile value" do
      expect(question.answers_per_row_mobile).to eq 6
    end
  end

  describe 'callbacks' do
    it_behaves_like 'Qrvey Synchronization callbacks' do
      def trigger_record
        @trigger_record ||= create(:question_without_possible_answers)
      end
    end

    describe '#set_slider_start_position' do
      context 'when it is slider type' do
        context 'when slider_start_position already has a value' do
          it 'respects that value' do
            start_position = 1
            question = create(:slider_question, slider_start_position: start_position)
            expect(question.slider_start_position).to eq start_position
          end
        end

        context 'when slider_submit_button_enabled has no value' do
          it 'sets the value to half the number of pips(associated possible answers)' do
            question = create(:slider_question)
            expect(question.slider_start_position).to eq(question.possible_answers.size / 2)
          end
        end

        context 'when it is not slider type' do
          it 'leaves slider_submit_button_enabled as nil' do
            question = create(:question)
            expect(question.slider_start_position).to be_nil
          end
        end
      end
    end

    describe '#set_slider_submit_button_enabled' do
      context 'when it is slider type' do
        context 'when slider_submit_button_enabled already has a value' do
          it 'respects that value' do
            question = create(:slider_question, slider_submit_button_enabled: false)
            expect(question.slider_submit_button_enabled).to be false
          end
        end

        context 'when slider_submit_button_enabled has no value' do
          it 'sets the value to true' do
            question = create(:slider_question)
            expect(question.slider_submit_button_enabled).to be true
          end
        end
      end

      context 'when it is not slider type' do
        it 'leaves slider_submit_button_enabled as nil' do
          question = create(:question)
          expect(question.slider_submit_button_enabled).to be_nil
        end
      end
    end
  end

  describe "answer_counts" do
    let(:question) { create(:question) }
    let(:possible_answer) { question.possible_answers.first }

    def make_answer(submission_extras: {}, answer_extras: {})
      submission = create(:submission, **submission_extras)
      create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        expect(question.answers_count(filters: filters)).to eq(
          Answer.answers_count(question.answers, filters: filters)
        )
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answer and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(answer_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_answer(submission_extras: { visit_count: attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    it 'returns the number of submissions for a multiple_choices question type' do
      survey = create(:survey)
      question = create(:multiple_choices_question, survey: survey)
      device = create(:device, udid: udid)
      submission = create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)
      group_udid = true

      create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.first.id)
      create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.last.id)

      expect(Answer.count).to eq 2
      expect(question.reload.answers_count(group_udid)).to eq 1
    end
  end

  describe 'answer_rates' do
    let(:survey) { create(:survey) }

    def make_answer(submission_extras: {}, answer_extras: {})
      first_question_id = survey.questions.first.id
      last_question_id = survey.questions.last.id

      submission = create(:submission, **submission_extras)
      create(:answer, question_id: first_question_id, submission: submission, **answer_extras)

      submission = create(:submission, **submission_extras)
      create(:answer, question_id: first_question_id, submission: submission, **answer_extras)

      submission = create(:submission, **submission_extras)
      create(:answer, question_id: last_question_id, submission: submission, **answer_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        survey.questions.each do |question|
          possible_answer_rates = question.answer_rates(filters: filters)
          answers_count_for_question = question.answers_count(filters: filters)

          possible_answer_rates.each do |possible_answer_rate|
            expected_answer_count = possible_answer_rate[:possible_answer].answers_count(filters: filters) # possible_answer.answers_count
            expect(possible_answer_rate[:answers_count]).to eq(expected_answer_count)

            expected_rate = answers_count_for_question.zero? ? 0 : (expected_answer_count.to_f / answers_count_for_question)
            expect(possible_answer_rate[:answer_rate]).to eq(expected_rate)
          end
        end
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answer and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(answer_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_answer(submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end

  describe '#due_for_tag_automation?' do
    context 'when a question does not have TagAutomationWorker enabled' do
      it 'returns false' do
        question = create(:free_text_question)
        create(:tag, question: question)
        expect(question.due_for_tag_automation?).to be false
      end
    end

    context 'when a question is not a free text question' do
      it 'returns false' do
        question = create(:question, tag_automation_worker_enabled: true)
        create(:tag, question: question)
        expect(question.due_for_tag_automation?).to be false
      end
    end

    context 'when a question does not own any tags' do
      it 'returns false' do
        question = create(:free_text_question, tag_automation_worker_enabled: true)
        expect(question.due_for_tag_automation?).to be false
      end
    end

    context 'when a question is free text, has TagAutomationWorker enabled, and owns tags' do
      it 'returns true' do
        question = create(:free_text_question, tag_automation_worker_enabled: true)
        create(:tag, question: question)
        expect(question.due_for_tag_automation?).to be true
      end
    end
  end

  describe "filtered_answers_count" do
    let(:question) { create(:question) }

    before do
      make_answer(question.possible_answers.sort_by_position.first, answer_extras: { created_at: "2022-01-13".to_datetime})
      make_answer(question.possible_answers.sort_by_position.first, answer_extras: { created_at: "2022-05-13".to_datetime })
      make_answer(question.possible_answers.sort_by_position.last, answer_extras: { created_at: "2022-12-13".to_datetime })

      @submission_ids = Submission.order(:created_at).pluck(:id).first(Submission.count - 1)
    end

    def answer_counts_per_possible_answer(scope)
      scope.group("answers.possible_answer_id").count
    end

    def set_up_multiple_choice_question
      question.update(question_type: "multiple_choices_question")
      make_answer(question.possible_answers.sort_by_position.last, answer_extras: { submission: Submission.order(:created_at)[1] })
    end

    def make_answer(possible_answer, submission_extras: {}, answer_extras: {})
      submission = create(:submission, **submission_extras)
      create(:answer, submission: submission, possible_answer: possible_answer, question: possible_answer.question, **answer_extras)
    end

    it "has the expected structure" do
      result = question.filtered_answers_count([])
      expected_keys = %i(responses answers ungrouped_responses)

      expect(result.keys).to match_array(expected_keys)

      expect(result[:responses].is_a?(Integer)).to be(true)
      expect(result[:answers].is_a?(Hash)).to be(true)
      expect(result[:ungrouped_responses].is_a?(Integer)).to be(true)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        result = question.filtered_answers_count([], filters: filters)

        filtered_answers = Answer.filtered_answers(question.answers, filters: filters)

        expect(result[:responses]).to eq filtered_answers.count
        expect(result[:answers]).to eq filtered_answers.group("answers.possible_answer_id").count
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        possible_answer = question.possible_answers.sort_by_position.first
        make_answer(possible_answer) and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(possible_answer, answer_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_answer(possible_answer, submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    context "when no submissions are provided" do
      def answer_scope
        Answer.filtered_answers(question.answers)
      end

      context "with a multiple choice question" do
        before do
          set_up_multiple_choice_question
        end

        it "has the expected values" do
          result = question.filtered_answers_count([])

          group_by_submission_id = true

          expect(result[:responses]).to eq question.answers_count(group_by_submission_id)
          expect(result[:answers]).to eq answer_counts_per_possible_answer(answer_scope)
          expect(result[:ungrouped_responses]).to eq question.answers_count
        end
      end

      it "has the expected values" do
        result = question.filtered_answers_count([])

        expect(result[:responses]).to eq question.answers_count
        expect(result[:answers]).to eq answer_counts_per_possible_answer(answer_scope)
        expect(result[:ungrouped_responses]).to eq question.answers_count
      end
    end

    context "when submissions are provided" do
      def answer_scope
        answer_scope = Answer.filtered_answers(question.answers)
        answer_scope = answer_scope.where(answers: { submission_id: @submission_ids })
      end

      context "with a multiple choice question" do
        before do
          set_up_multiple_choice_question
        end

        it "has the expected values" do
          result = question.filtered_answers_count(@submission_ids)

          expect(result[:responses]).to eq answer_scope.count("distinct(submission_id)")
          expect(result[:answers]).to eq answer_counts_per_possible_answer(answer_scope)
          expect(result[:ungrouped_responses]).to eq answer_scope.count
        end
      end

      it "has the expected values" do
        result = question.filtered_answers_count(@submission_ids)

        expect(result[:responses]).to eq answer_scope.count
        expect(result[:answers]).to eq answer_counts_per_possible_answer(answer_scope)
        expect(result[:ungrouped_responses]).to eq answer_scope.count
      end
    end
  end
end
