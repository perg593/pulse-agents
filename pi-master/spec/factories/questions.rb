# frozen_string_literal: true
FactoryBot.define do
  factory :question do
    sequence(:content) { FFaker::Lorem.phrase }
    survey
    after(:create) do |question, _evaluator|
      create_list(:possible_answer, 2, question: question)
    end
  end

  factory :question_without_possible_answers, class: "Question" do
    sequence(:content) { FFaker::Lorem.phrase }
    survey
  end

  factory :free_text_question, class: 'Question' do
    content { "What is the universe?" }
    question_type { 1 }
    survey
  end

  factory :custom_content_question, class: 'Question' do
    content { "Why Ekohe is awesome?" }
    custom_content { "<p>Lorem Ipsum.</p>" }
    question_type { 2 }
    survey
  end

  factory :multiple_choices_question, class: 'Question' do
    content { FFaker::Lorem.unique.sentence }
    question_type { 3 }
    survey

    after(:create) do |question, _evaluator|
      create_list(:possible_answer, 2, question: question)
    end
  end

  factory :single_choice_question, class: 'Question' do
    content { FFaker::Lorem.unique.sentence }
    question_type { 0 }
    survey

    after(:create) do |question, _evaluator|
      create_list(:possible_answer, 2, question: question)
    end
  end

  factory :nps_question, class: 'Question' do
    content { "What is the universe?" }
    question_type { 0 }
    survey
    nps { true }

    after(:create) do |question, _evaluator|
      create_list(:possible_answer, Question::NUM_NPS_POSSIBLE_ANSWERS, question: question)
    end
  end

  factory :slider_question, class: 'Question' do
    content { FFaker::Lorem.unique.sentence }
    question_type { 4 }
    slider_start_position { 2 }
    slider_submit_button_enabled { true }
    survey

    after(:create) do |question, _evaluator|
      ('a'..'z').to_a.sample(5).each { |pip_label| create(:possible_answer, question: question, content: pip_label) }
    end
  end
end
