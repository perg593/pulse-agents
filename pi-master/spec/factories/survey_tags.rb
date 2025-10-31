# frozen_string_literal: true

FactoryBot.define do
  factory :survey_tag do
    name { FFaker::Lorem.unique.word }
    account
  end
end
