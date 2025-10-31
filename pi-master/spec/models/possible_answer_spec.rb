# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe PossibleAnswer do
  before do
    described_class.delete_all
  end

  describe "validations" do
    it_behaves_like "color validation" do
      subject { create(:possible_answer) }

      let(:attribute_to_validate) { :report_color }
    end

    it_behaves_like 'Qrvey Synchronization callbacks' do
      def trigger_record
        @trigger_record ||= create(:possible_answer)
      end
    end

    it 'ensures sizes are in the specified format' do
      possible_answer = create(:possible_answer)

      good_values = %w(10px 10% 10)
      good_values.each do |good_value|
        possible_answer.image_height = good_value
        expect(possible_answer.valid?).to be true
      end
      bad_values = %w(10pc a10% tall)
      bad_values.each do |bad_value|
        possible_answer.image_height = bad_value
        expect(possible_answer.valid?).to be false
      end
    end

    def create_standalone_question
      create(:question_without_possible_answers, survey: create(:survey_without_question))
    end

    it "is able to create a possible_answer" do
      question = create_standalone_question

      possible_answer = described_class.create(content: FFaker::Lorem.phrase, question_id: question.id)

      expect(possible_answer.valid?).to be true
      expect(described_class.count).to eq(1)
    end

    it "cannot link to its own question" do
      question = create_standalone_question

      possible_answer = described_class.create(content: FFaker::Lorem.phrase, question_id: question.id, next_question_id: question.id)

      expect(possible_answer.valid?).to be false
      expect(possible_answer.errors[:next_question_id].present?).to be true
      expect(described_class.count).to eq(0)
    end

    context 'with multiple choice questions' do
      let(:multiple_choices_question) { create(:multiple_choices_question) }

      context 'when it is the last possible answer' do
        let(:possible_answer) { multiple_choices_question.possible_answers.sort_by_position.last }

        it 'is allowed to have a next question' do
          possible_answer.next_question = create(:question)
          expect(possible_answer.valid?).to be true
        end
      end

      context 'when it is not the last possible answer' do
        let(:possible_answer) { multiple_choices_question.possible_answers.sort_by_position.first }

        it 'can not have a next question unless it is the last possible answer' do
          expect(possible_answer.valid?).to be true
          possible_answer.next_question = create(:question)
          expect(possible_answer.valid?).to be false
        end
      end
    end
  end

  describe "#answers_count" do
    let(:possible_answer) { create(:possible_answer) }

    def make_answer(submission_extras: {}, answer_extras: {})
      submission = create(:submission, **submission_extras)
      create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        expect(possible_answer.answers_count(filters: filters)).to eq(
          Answer.answers_count(possible_answer.answers, filters: filters)
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
  end

  describe "#event_answer_count" do
    let(:possible_answer) { create(:possible_answer) }
    let(:device) { create(:device) }
    let(:event) { create(:page_event, name: 'event test', device: device) }

    def make_answer(submission_extras: {}, answer_extras: {})
      submission = create(:submission, device: device, **submission_extras)
      create(:answer, submission: submission, possible_answer: possible_answer, **answer_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        answers = possible_answer.answers.joins(:page_events).where(page_events: { name: event.name }).distinct
        event_answer_count = Answer.answers_count(answers, filters: filters)
        expect(possible_answer.event_answer_count(event.name, filters: filters)).to eq event_answer_count
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answer and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(answer_extras: { created_at: attribute_value })
        when :device_type, :pageview_count, :visit_count
          make_answer(submission_extras: { filter_attribute => attribute_value })
        when :url
          # TODO: support url filter
        when :possible_answer_id
          make_possible_answer_filter_records(possible_answer.question.survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end
end
