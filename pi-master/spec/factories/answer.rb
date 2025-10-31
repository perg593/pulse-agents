# frozen_string_literal: true
FactoryBot.define do
  factory :answer do
    question factory: %i(question)
    submission factory: %i(submission)
    possible_answer { question.possible_answers.first }
  end

  factory :free_text_answer, class: "Answer" do
    question factory: :free_text_question
    submission
    text_answer { FFaker::Lorem.unique.sentence }
    question_type { :free_text_question }
  end
end
