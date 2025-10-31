# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AIOutlineGeneration do
  let(:survey) { create(:survey) }
  let(:device) { create(:device) }
  let(:question) { create(:question, survey: survey, question_type: :free_text_question) }
  let(:submission) { create(:submission, survey: survey, device: device) }
  let(:answer) { create(:answer, submission: submission, question: question, text_answer: 'Test response') }
  let(:ai_outline_job) { create(:ai_outline_job, survey: survey) }

  before do
    # Ensure we have the necessary data
    submission.update!(answers_count: 1)
    answer # Create the answer
  end

  describe '.generate_outline' do
    it 'creates a new Generator instance and calls generate_outline' do
      generator = instance_double(AIOutlineGeneration::Generator)
      allow(AIOutlineGeneration::Generator).to receive(:new).and_return(generator)
      expect(generator).to receive(:generate_outline).with(ai_outline_job)

      described_class.generate_outline(ai_outline_job)
    end
  end

  describe AIOutlineGeneration::Generator do
    let(:generator) { described_class.new }

    describe '#generate_outline' do
      before do
        allow(Claude).to receive_messages(token_count: 100, prompt_exceeds_limit?: false)
        allow(generator).to receive(:request_outline).and_return('Generated outline')
      end

      it 'generates an outline successfully' do
        result = generator.generate_outline(ai_outline_job)
        expect(result).to eq('Generated outline')
      end

      it 'logs the start and end times' do
        expect(generator.tagged_logger).to receive(:info).with(/Started AI outline generation/)
        expect(generator.tagged_logger).to receive(:info).with(/Generated prompt with/)
        expect(generator.tagged_logger).to receive(:info).with(/Prompt:/)
        expect(generator.tagged_logger).to receive(:info).with(/Finished AI outline generation/)

        generator.generate_outline(ai_outline_job)
      end

      context 'when prompt exceeds token limit' do
        before do
          # Mock the Claude.chat method for truncated requests
          allow(Claude).to receive_messages(prompt_exceeds_limit?: true, chat: {
                                              "choices" => [
                                                {
                                                  "message" => {
                                                    "content" => "Truncated outline"
                                                  }
                                                }
                                              ]
                                            })
        end

        it 'truncates the prompt and logs a warning' do
          expect(generator.tagged_logger).to receive(:warn).with('Prompt exceeds token limit, truncating data')
          expect(generator).to receive(:request_outline).with(anything)

          generator.generate_outline(ai_outline_job)
        end
      end
    end

    describe 'integration tests' do
      before do
        # Mock the Claude.chat method directly
        allow(Claude).to receive(:chat).and_return({
                                                     "choices" => [
                                                       {
                                                         "message" => {
                                                           "content" => "Generated outline"
                                                         }
                                                       }
                                                     ]
                                                   })
      end

      it 'can generate outline without errors' do
        expect { generator.generate_outline(ai_outline_job) }.not_to raise_error
      end

      context 'with filters' do
        let(:ai_outline_job) do
          create(:ai_outline_job, survey: survey, filters: {
                   'date_range' => '2023-01-01..2023-12-31',
            'device_filter' => ['mobile']
                 })
        end

        before do
          # Mock the Claude.chat method for filtered requests
          allow(Claude).to receive(:chat).and_return({
                                                       "choices" => [
                                                         {
                                                           "message" => {
                                                             "content" => "Generated outline with filters"
                                                           }
                                                         }
                                                       ]
                                                     })
        end

        it 'can generate outline with filters without errors' do
          expect { generator.generate_outline(ai_outline_job) }.not_to raise_error
        end
      end

      context 'with comprehensive data' do
        let(:device) { create(:device) } # Use factory defaults for valid UDID
        let(:submission) { create(:submission, survey: survey, device: device, device_type: 'mobile', pageview_count: 5, visit_count: 2, url: 'https://example.com', custom_data: { 'source' => 'email' }) }
        let(:answer) { create(:answer, submission: submission, question: question, text_answer: 'Test response') }

        before do
          submission.update!(answers_count: 1)
          answer # Create the answer

          # Mock the Claude.chat method for comprehensive data
          allow(Claude).to receive(:chat).and_return({
                                                       "choices" => [
                                                         {
                                                           "message" => {
                                                             "content" => "Generated comprehensive outline"
                                                           }
                                                         }
                                                       ]
                                                     })
        end

        it 'can generate comprehensive outline successfully' do
          expect(Claude).to receive(:chat).with(include('Survey Information'), max_tokens: 4000)

          result = generator.generate_outline(ai_outline_job)

          expect(result).to be_a(String)
          expect(result).to include('Generated comprehensive outline')
        end
      end
    end
  end
end
