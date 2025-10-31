# frozen_string_literal: true

class TagAutomationJob < ActiveRecord::Base
  belongs_to :question

  has_many :tag_automation_job_answers, dependent: :destroy
  has_many :answers, through: :tag_automation_job_answers

  has_many :applied_tags
  has_many :tagged_answers, through: :applied_tags, source: :answer

  enum status: { in_progress: 0, completed: 1, failed: 2 }

  accepts_nested_attributes_for :tag_automation_job_answers

  # Playing it safe to avoid exceeding the token size limit, as speed is less critical given the asynchronous processing
  ANSWER_BATCH_SIZE = 500

  def auto_tag
    answers.auto_tag_eligible.find_in_batches(batch_size: ANSWER_BATCH_SIZE).each do |answer_batch|
      request_auto_tag(answer_batch).each do |applied_tag_attributes|
        tag = question.tags.find_by(name: applied_tag_attributes['tag']) || Tag.placeholder(question)
        answer = question.answers.find_by(id: applied_tag_attributes['answer_id']) # Can't perform text search due to the lack of a unique index
        applied_tags.create(tag: tag, answer: answer, is_good_automation: false) if answer
      end
    end
  end

  private

  def request_auto_tag(answers)
    prompt = <<~STR
      Label the provided answers based on the given tags. Output raw JSON, without wrapping it in backticks, and include "answer_id" field and "tag" field for each answer. If an answer does not correspond to any tag, leave the "tag" field empty. Here is an example: [{"answer_id": 123, "tag": "intrigued"}].
      Tags and their corresponding answers: #{tagging_examples}
      Answers to label: #{answers.pluck(:id, :text_answer)}
    STR
    response = GPT.chat(prompt)
    labelled_answers = JSON.parse(response['choices'][0]['message']['content'])

    unless labelled_answers.all? { |labelled_answer| labelled_answer.is_a?(Hash) }
      Rollbar.error("Autotag Error", "Autotag - ChatGPT didn't return an array of hashes", chat_gtp_response: response)
      return {}
    end

    labelled_answers
  end

  def tagging_examples
    @tagging_examples ||= sample_tags.includes(:manually_tagged_answers).map { |tag| { tag: tag.name, answers: tag.sample_manually_tagged_answer_texts } }
  end

  def sample_tags
    question.tags.order('RANDOM()')
  end
end

# == Schema Information
#
# Table name: tag_automation_jobs
#
#  id          :bigint           not null, primary key
#  status      :integer          default("in_progress"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  question_id :bigint
#
# Indexes
#
#  index_tag_automation_jobs_on_question_id  (question_id)
#
