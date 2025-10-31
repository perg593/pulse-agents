# frozen_string_literal: true

FactoryBot.define do
  factory :personal_data_setting do
    masking_enabled { false }
    phone_number_masked { false }
    email_masked { false }
    account { nil }
  end
end
