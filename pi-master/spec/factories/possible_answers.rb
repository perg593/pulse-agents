# frozen_string_literal: true
FactoryBot.define do
  factory :possible_answer do
    sequence(:content) { FFaker::Lorem.phrase }
    question
  end
end
