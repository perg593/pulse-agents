# frozen_string_literal: true
require 'spec_helper'

describe AITagRecommendation do
  let(:question) { create(:question) }

  it 'deduplicates tag recommendations' do
    existing_tag_name = create(:tag, question: question).name
    new_tag_name = FFaker::Lorem.unique.word

    gpt_response = {
      'choices' => [
        {
          'message' => {
            'content' => {
              categories: [
                { name: existing_tag_name }, { name: new_tag_name }
              ]
            }.to_json
          }
        }
      ]
    }
    allow(GPT).to receive(:chat).and_return(gpt_response)

    expect(described_class.request(question: question)).to eq [{ 'name' => new_tag_name }]
  end

  it 'ensures that the prompt size is under the set limit' do
    stub_const('GPT::MAX_CONTEXT_TOKENS', 200)
    stub_const("#{described_class}::MAX_COMPLETION_SIZE", 100)
    prompt_token_limit = GPT::MAX_CONTEXT_TOKENS

    10.times.map { create(:answer, question: question, text_answer: FFaker::Lorem.sentence) }

    prompt = described_class.prompt(question: question, answers: question.answers)
    expect(GPT.token_count(prompt)).to be < prompt_token_limit
  end
end
