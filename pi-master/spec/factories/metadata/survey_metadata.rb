# frozen_string_literal: true
FactoryBot.define do
  factory :survey_metadatum, class: "Metadata::SurveyMetadatum" do
    name { FFaker::Lorem.unique.word }
    survey
  end
end
