# frozen_string_literal: true
FactoryBot.define do
  factory :question_metadatum, class: "Metadata::QuestionMetadatum" do
    name { FFaker::Lorem.unique.word }
    question
  end
end
