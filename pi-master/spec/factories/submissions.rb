# frozen_string_literal: true
FactoryBot.define do
  factory :submission do
    answers_count { 0 }
    udid { '00000000-0000-4000-f000-000000000001' }

    survey factory: %i(survey)
    device factory: %i(device)
  end
end
