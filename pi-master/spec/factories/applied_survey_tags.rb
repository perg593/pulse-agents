# frozen_string_literal: true

FactoryBot.define do
  factory :applied_survey_tag do
    survey_tag
    survey
  end
end
