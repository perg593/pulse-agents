# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Claude do
  describe '.chat' do
    let(:prompt) { "Hello, Claude! Please provide a brief response." }
    let(:mock_client) { instance_double(Anthropic::Client) }
    let(:mock_messages) { instance_double('messages') } # rubocop:disable RSpec/VerifiedDoubleReference

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)
    end

    context 'when API call succeeds' do
      before do
        allow(mock_messages).to receive(:create).and_return(
          double(
            content: [double(text: "Hello! I'm Claude, an AI assistant.")]
          )
        )
      end

      it 'calls the Anthropic API and returns formatted response' do
        response = described_class.chat(prompt)

        expect(response).to be_a(Hash)
        expect(response["choices"]).to be_an(Array)
        expect(response["choices"].first["message"]["content"]).to eq("Hello! I'm Claude, an AI assistant.")
      end
    end

    context 'when API call fails' do
      before do
        allow(mock_messages).to receive(:create).and_raise(
          Anthropic::Errors::APIError.new(url: "https://api.anthropic.com", message: "API key invalid")
        )
      end

      it 'returns error response' do
        response = described_class.chat(prompt)

        expect(response).to be_a(Hash)
        expect(response["error"]).to eq("API key invalid")
      end
    end
  end

  describe '.token_count' do
    it 'estimates token count based on character length' do
      text = "This is a test message with some content."
      expected_tokens = (text.length / 4.0).ceil

      expect(described_class.token_count(text)).to eq(expected_tokens)
    end
  end

  describe '.prompt_exceeds_limit?' do
    it 'returns true when prompt exceeds context limit' do
      long_prompt = "x" * (Claude::MAX_CONTEXT_TOKENS * 5) # 5x the limit

      expect(described_class.prompt_exceeds_limit?(long_prompt)).to be true
    end

    it 'returns false when prompt is within limit' do
      short_prompt = "This is a short prompt."

      expect(described_class.prompt_exceeds_limit?(short_prompt)).to be false
    end
  end
end
