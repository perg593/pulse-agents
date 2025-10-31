# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe Control::PageEventPresenter do
  include Rails.application.routes.url_helpers

  let(:device) { create(:device) }
  let!(:event) { create(:page_event, name: 'event test', device: device, account: survey.account) }

  let(:survey) { create(:survey) }
  let(:question) { survey.questions.first }

  let(:mock_color) { FFaker::Color.name }

  describe 'page_event_params' do
    context 'when there is no question' do
      it 'returns nothing' do
        survey.questions.destroy_all
        presenter = described_class.new(survey: survey, event: create(:page_event, account: survey.account))
        expect(presenter.page_event_params).to be_nil
      end
    end

    context 'when there is no event' do
      it 'returns nothing' do
        survey.account.page_events.destroy_all
        presenter = described_class.new(survey: survey, question: survey.questions.first)
        expect(presenter.page_event_params).to be_nil
      end
    end

    it_behaves_like "filter sharing" do
      # rubocop:disable Metrics/AbcSize
      def it_filters(filters)
        return true if filters.include?(:completion_urls) # TODO: Support URL filter

        presenter = described_class.new(survey: survey, filters: filters)
        allow(presenter).to receive(:color).and_return mock_color
        page_event_params = presenter.page_event_params

        selected_question_data = {
          id: question.id,
          content: question.content,
          answerCount: question.answers_count(filters: filters),
          possibleAnswers: possible_answer_data(question, event, filters)
        }

        expect(page_event_params[:questions]).to eq survey.questions.map { |q| { id: q.id, content: q.content } }
        expect(page_event_params[:events].pluck(:name)).to eq survey.account.page_events.order(:name).pluck(:name)
        expect(page_event_params[:selectedQuestion]).to eq selected_question_data
        expect(page_event_params[:selectedEvent]).to eq({ name: event.name })
        expect(page_event_params[:itemUpdateUrl]).to eq page_event_data_survey_path(survey)
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answers_with_page_events and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answers_with_page_events(answer_extras: { created_at: attribute_value })
        when :device_type, :pageview_count, :visit_count
          make_answers_with_page_events(submission_extras: { filter_attribute => attribute_value })
        when :url
          # TODO: Suppport URL filter
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end

  describe 'item_update_params' do
    context 'when the question was not found' do
      it 'returns nothing' do
        presenter = described_class.new(survey: survey, event: create(:page_event, account: survey.account))
        expect(presenter.item_update_params).to be_nil
      end
    end

    context 'when the event was not found' do
      it 'returns nothing' do
        presenter = described_class.new(survey: survey, question: survey.questions.first)
        expect(presenter.item_update_params).to be_nil
      end
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        return true if filters.include?(:completion_urls) # TODO: Support URL filter

        presenter = described_class.new(survey: survey, question: question, event: event, filters: filters)
        allow(presenter).to receive(:color).and_return mock_color
        item_update_params = presenter.item_update_params

        expect(item_update_params[:id]).to eq question.id
        expect(item_update_params[:content]).to eq question.content
        expect(item_update_params[:answerCount]).to eq question.answers_count(filters: filters)
        expect(item_update_params[:possibleAnswers]).to eq possible_answer_data(question, event, filters)
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answers_with_page_events and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answers_with_page_events(answer_extras: { created_at: attribute_value })
        when :device_type, :pageview_count, :visit_count
          make_answers_with_page_events(submission_extras: { filter_attribute => attribute_value })
        when :url
          # TODO: Suppport URL filter
        when :possible_answer_id
          make_possible_answer_filter_records(survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end
  end

  describe 'Rounded vs Truncated' do
    # 5 answers with an event to the first question
    # 2 answers without an event each answering the first and the last questions respectively
    before do
      5.times do
        submission_with_event = create(:submission, survey: survey, device: device) # Associated with a device that has an event
        create(:answer, submission: submission_with_event, question: question, possible_answer: question.possible_answers.first)
      end
      question.possible_answers.each do |possible_answer|
        submission_without_event = create(:submission, survey: survey)
        create(:answer, submission: submission_without_event, question: question, possible_answer: possible_answer)
      end
    end

    describe 'page_event_params' do
      it 'rounds the answer rates' do
        presenter = described_class.new(survey: survey)
        page_event_params = presenter.page_event_params
        # the num of answers for the possible answer(6) / the num of answers for the question(7)
        expect(page_event_params[:selectedQuestion][:possibleAnswers][0][:answerRate]).to eq 86 # 85.7
        # the num of answers made for the possible answer while a certain event was in place(5) / the num of answers for the possible answer(6)
        expect(page_event_params[:selectedQuestion][:possibleAnswers][0][:eventAnswerRate]).to eq 83 # 83.3
      end
    end

    describe 'item_update_params' do
      it 'rounds the answer rates' do
        presenter = described_class.new(survey: survey, question: question, event: event)
        item_update_params = presenter.item_update_params
        # the num of answers for the possible answer(6) / the num of answers for the question(7)
        expect(item_update_params[:possibleAnswers][0][:answerRate]).to eq 86 # 85.7
        # the num of answers made for the possible answer while a certain event was in place(5) / the num of answers for the possible answer(6)
        expect(item_update_params[:possibleAnswers][0][:eventAnswerRate]).to eq 83 # 83.3
      end
    end
  end

  def make_answers_with_page_events(submission_extras: {}, answer_extras: {})
    question = survey.questions.first
    possible_answer = question.possible_answers.first
    submission_with_event = create(:submission, survey: survey, device: device, **submission_extras) # Associated with a device that has an event
    create(:answer, submission: submission_with_event, question: question, possible_answer: possible_answer, **answer_extras)
    submission_without_event = create(:submission, **submission_extras)
    create(:answer, submission: submission_without_event, question: question, possible_answer: possible_answer, **answer_extras)
  end

  def possible_answer_data(question, event, filters)
    question_answer_count = question.answers_count(filters: filters)
    question.possible_answers.map do |pa|
      pa_answer_count = pa.answers_count(filters: filters)
      pa_answer_rate = question_answer_count.zero? ? 0 : pa_answer_count * 100 / question_answer_count
      event_answer_count = pa.event_answer_count(event.name, filters: filters)
      event_answer_rate =pa_answer_count.zero? ? 0 : event_answer_count * 100 / pa_answer_count
      { id: pa.id, content: pa.content, color: mock_color, colorUpdateUrl: "/possible_answers/#{pa.id}/update_color",
        answerCount: pa_answer_count, answerRate: pa_answer_rate, eventAnswerCount: event_answer_count, eventAnswerRate: event_answer_rate }
    end
  end
end
