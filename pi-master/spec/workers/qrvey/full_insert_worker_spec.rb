# frozen_string_literal: true

require 'spec_helper'

describe Qrvey::FullInsertWorker do
  let(:worker) { described_class.new }

  let(:custom_start_time) { Time.new(2023, 7, 23, 0, 0, 0, 'utc') }
  let(:custom_end_time) { Time.new(2023, 7, 25, 0, 0, 0, 'utc') }

  let(:survey) { create(:survey) }
  let(:question) { survey.questions.sample }
  let(:possible_answer) { question.possible_answers.sample }

  before do
    10.times do
      random_time = rand(custom_start_time...custom_end_time)
      submission = create(:submission, survey: survey, answers_count: 1, created_at: random_time)
      create(:answer, submission: submission, question: question, possible_answer: possible_answer, updated_at: random_time)
    end
  end

  it 'filters answers based on timestamps' do
    filtered_answer_count = survey.answers.count

    # Answers out of the time range
    [custom_start_time - 1.minute, custom_end_time + 1.minute].each do |created_at|
      submission = create(:submission, survey: survey, answers_count: 1)
      create(:answer, submission: submission, question: question, possible_answer: possible_answer, updated_at: created_at)
    end

    # Read what's passed to #stream_csv_to_s3
    string_io = StringIO.new
    allow(worker).to receive(:stream_csv_to_s3).and_yield(string_io)

    worker.perform(custom_start_time: custom_start_time, custom_end_time: custom_end_time)

    string_io.rewind
    lines = string_io.readlines
    csv_lines = lines.first.split('[')
    expect(csv_lines.reject(&:empty?).length).to eq(filtered_answer_count + 1) # "+1" is for the header row
  end
end
