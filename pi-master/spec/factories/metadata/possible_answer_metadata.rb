# frozen_string_literal: true
FactoryBot.define do
  factory :possible_answer_metadatum, class: "Metadata::PossibleAnswerMetadatum" do
    name { FFaker::Lorem.unique.word }
    possible_answer
  end
end
