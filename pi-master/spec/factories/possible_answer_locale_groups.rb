# frozen_string_literal: true
FactoryBot.define do
  factory :possible_answer_locale_group do
    name { FFaker::Lorem.phrase }
    question_locale_group
  end
end
