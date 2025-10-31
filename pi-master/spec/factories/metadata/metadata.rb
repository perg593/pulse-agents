# frozen_string_literal: true
FactoryBot.define do
  factory :metadatum do
    type { "" }
    name { "MyString" }
    owner_record_id { nil }
  end
end
