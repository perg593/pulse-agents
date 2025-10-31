# frozen_string_literal: true

module GPT
  MODEL = "gpt-4o"
  MAX_OUTPUT_TOKENS = 16_384
  MAX_CONTEXT_TOKENS = 128_000

  def self.chat(prompt, max_tokens: MAX_OUTPUT_TOKENS, logger: Rails.logger)
    client = OpenAI::Client.new do |config|
      config.response :logger, logger, bodies: true, errors: true
    end

    client.chat( # https://platform.openai.com/docs/api-reference/chat/create
      parameters: {
        model: MODEL,
        messages: [{ role: "user", content: prompt }],
        max_tokens: max_tokens
      }
    )
  end

  def self.token_count(input)
    Tiktoken.encoding_for_model(MODEL).encode(input).length
  end

  def self.prompt_exceeds_limit?(prompt)
    token_count(prompt) > MAX_CONTEXT_TOKENS
  end
end
