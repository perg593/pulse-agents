# frozen_string_literal: true
FactoryBot.define do
  factory :tag do
    name { FFaker::Lorem.unique.word }
    color { FFaker::Color.name }
    question
  end
end
