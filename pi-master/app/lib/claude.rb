# frozen_string_literal: true

module Claude
  MODEL = "claude-3-5-sonnet-20241022"
  MAX_OUTPUT_TOKENS = 16_384
  MAX_CONTEXT_TOKENS = 200_000

  def self.chat(prompt, max_tokens: MAX_OUTPUT_TOKENS)
    client = Anthropic::Client.new(
      api_key: Rails.application.credentials.dig(:anthropic, :api_key)
    )

    response = client.messages.create(
      model: MODEL,
      max_tokens: max_tokens,
      messages: [{ role: "user", content: prompt }]
    )

    # Return response in the same format as GPT for compatibility
    {
      "choices" => [
        {
          "message" => {
            "content" => response.content.first.text
          }
        }
      ]
    }
  rescue Anthropic::Errors::APIError => e
    {
      "error" => e.message
    }
  end

  def self.token_count(input)
    # Claude uses a different tokenizer than GPT, but for now we'll use a rough estimate
    # 1 token ≈ 4 characters for English text
    (input.length / 4.0).ceil
  end

  def self.prompt_exceeds_limit?(prompt)
    token_count(prompt) > MAX_CONTEXT_TOKENS
  end
end
