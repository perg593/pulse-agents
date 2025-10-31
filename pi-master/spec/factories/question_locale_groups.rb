# frozen_string_literal: true
FactoryBot.define do
  factory :question_locale_group do
    name { FFaker::Lorem.phrase }
    survey_locale_group
  end
end
