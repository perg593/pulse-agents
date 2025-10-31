# frozen_string_literal: true

class AITagRecommendation
  MAX_COMPLETION_SIZE = 300 # We're only requesting 6 tag recommendations
  ANSWER_BATCH_SIZE = 10 # Avoid fetching all answers at once while also minimizing empty space in the prompt

  def self.request(question:)
    prompt = prompt(question: question, answers: question.answers.auto_tag_eligible.order('RANDOM()'))

    response = GPT.chat(prompt, max_tokens: MAX_COMPLETION_SIZE)
    tag_recommendations = JSON.parse(response['choices'][0]['message']['content'])['categories']

    existing_tag_names = question.tags.pluck(:name)
    tag_recommendations.reject { |tag_recommendation| existing_tag_names.include?(tag_recommendation['name']) }
  end

  def self.prompt(question:, answers:)
    prompt = <<~STR
      Provide concise categories, up to 6, each within 20 characters, for a set of responses to a question. Output raw JSON, without wrapping it in backticks, with each entry containing a key "name".
      Question: #{question.content}
      Responses:
    STR

    answers.find_in_batches(batch_size: ANSWER_BATCH_SIZE) do |answer_batch|
      new_response_prompt = "#{prompt}\n#{answer_batch.pluck(:text_answer).join("\n")}"
      break if GPT.prompt_exceeds_limit?(new_response_prompt)
      prompt = new_response_prompt
    end

    prompt
  end
end
