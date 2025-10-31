# frozen_string_literal: true

require "logging"
require 'tiktoken_ruby'
require_relative '../app/lib/gpt'

module AISummarization
  STRATEGY_LAST_RESPONSES = "last responses"
  STRATEGY_RANDOM_SAMPLING = "random sampling"

  def self.summarize(answer_scope, strategy: STRATEGY_LAST_RESPONSES, max_response_tokens: 300)
    Summarizer.new.summarize(answer_scope, strategy: strategy, max_response_tokens: max_response_tokens)
  end

  class Summarizer
    include Logging

    CONTEXT_LENGTH_EXCEEDED_CODE = "context_length_exceeded"

    # rubocop:disable Metrics/AbcSize TODO: Address (retry) complexity
    def summarize(answer_scope, strategy:, max_response_tokens:)
      start_time = Time.current

      tagged_logger.info "Started"

      tagged_logger.info "Using strategy #{strategy}"

      default_prompt_token_count = GPT.token_count(prompt(""))
      @prompt_token_limit = GPT::MAX_CONTEXT_TOKENS - default_prompt_token_count - max_response_tokens

      response = Retryable.with_retry(max_retry_count: 2, logger: tagged_logger) do
        samples = sample_answers(answer_scope, strategy)
        tagged_logger.info "Sampled #{samples.count} responses. answer_ids: #{samples.pluck(:id)}"

        text_to_summarize = samples.pluck(:text_answer).join("\n ")

        tagged_logger.info "Prompt: #{prompt(text_to_summarize)}"

        tagged_logger.info "Capping response tokens at: #{max_response_tokens}"

        response = request_summary(text_to_summarize, max_response_tokens)

        if response.dig("error", "code") == CONTEXT_LENGTH_EXCEEDED_CODE
          tagged_logger.info "Lowering the prompt token limit"
          @prompt_token_limit -= 70 # The average number of tokens we understimate by, according to the logs.
          raise StandardError, response["error"]
        end

        response
      end

      raise StandardError, response["error"] if response["error"].present?

      response["choices"][0]["message"]["content"]
    ensure
      tagged_logger.info "Finished in #{Time.current - start_time}s"
    end

    # Samples answers according to the provided strategy
    # Limits the answer count to keep the total text under GPT's token limit
    def sample_answers(answer_scope, strategy)
      answer_scope = case strategy
      when STRATEGY_LAST_RESPONSES
        answer_scope.order(created_at: :desc)
      when STRATEGY_RANDOM_SAMPLING
        answer_scope.order("random()")
      else
        raise ArgumentError, "Invalid sampling strategy #{strategy}"
      end

      text_to_summarize = ""
      number_of_answers = 0

      answer_scope.each_with_index do |answer, i|
        text_to_summarize = "#{text_to_summarize}. #{answer.text_answer}"

        break if GPT.token_count(text_to_summarize) > @prompt_token_limit

        number_of_answers = i
      end

      answer_scope.limit(number_of_answers)
    end

    # Watch out for unnecessary whitespace, it'll eat into our tokens
    def prompt(text_to_summarize)
      result = <<~STR
        Provide a brief overview of the following customer feedback. The overview should be limited to 2 paragraphs focusing on the general sentiment of the customer voice as well as highlighting interesting comments. You may also suggest next steps for the business to act on based on the customer feedbacks but this is not always required.

        The customer feedbacks: #{text_to_summarize}

        The overview:
      STR

      result.strip
    end

    def request_summary(text_to_summarize, max_response_tokens)
      if Rails.env.development?
        {
          "choices" => [
            {
              "message" => {
                "content" => "Development placeholder. Avoid making costly live API calls"
              }
            }
          ]
        }
      else
        api_call_start_time = Time.current

        response = GPT.chat(prompt(text_to_summarize), max_tokens: max_response_tokens)

        api_call_duration = Time.current - api_call_start_time
        tagged_logger.info "Response: #{response} Took #{api_call_duration} #{'second'.pluralize(api_call_duration)}"

        response
      end
    end
  end
end
