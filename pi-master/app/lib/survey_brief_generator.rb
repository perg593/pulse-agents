# frozen_string_literal: true

require "logging"
require_relative "gpt"

class SurveyBriefGenerator
  include Logging

  BASE_PROMPT = <<~STR
    This is the configuration for a survey that is running on a website. In a
    single paragraph, based on the questions and targeting, outline what you
    think this survey is intending to learn from site visitors. Then, based on
    what you know about the company and CX optimization, outline how these
    learnings might be used or put into action to create value for the end user
    and the company.
  STR

  def initialize(survey)
    tagged_logger.info "Building context"

    @context = {
      survey_name: survey.name,
      targeting: survey_targeting(survey),
      questions: survey.questions.map do |question|
        {
          id: question.id,
          next_question_id: question.next_question_id,
          free_text_next_question_id: question.free_text_next_question_id,
          content: question.content,
          possible_answers: question.possible_answers.map do |possible_answer|
            {
              content: possible_answer.content,
              next_question_id: possible_answer.next_question_id
            }
          end
        }
      end
    }

    tagged_logger.info "Context built"
  end

  def generate
    start_time = Time.current

    tagged_logger.info "Started generating"

    tagged_logger.info "Requesting brief: #{prompt}"
    response = GPT.chat(prompt, max_tokens: 300)
    tagged_logger.info "Done generating"

    raise StandardError, response["error"] if response["error"].present?

    result = response.dig("choices", 0, "message", "content")

    tagged_logger.info "Final result: #{result}"

    result
  ensure
    tagged_logger.info "Finished in #{Time.current - start_time}s"
  end

  def prompt
    "#{BASE_PROMPT}\n#{@context}"
  end

  private

  def survey_targeting(survey)
    triggers_summary = Trigger.where(survey_id: survey.id).map(&:summarize).join(" ")

    "#{survey.summarize} #{triggers_summary}"
  end
end
