# frozen_string_literal: true

FactoryBot.define do
  factory :survey_recommendation do
    survey
    content { [{ title: "Test Recommendation" }] }
    filters { {} }
  end
end
