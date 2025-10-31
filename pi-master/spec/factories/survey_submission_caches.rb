# frozen_string_literal: true
FactoryBot.define do
  factory :survey_submission_cache do
    applies_to_date { FFaker::Time.unique.datetime }
    impression_count { rand(1000) }
    viewed_impression_count { rand(impression_count) }
    submission_count { rand(viewed_impression_count) }
  end
end
