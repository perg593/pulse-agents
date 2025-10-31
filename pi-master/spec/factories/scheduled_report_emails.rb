# frozen_string_literal: true
FactoryBot.define do
  factory :scheduled_report_email do
    email { FFaker::Internet.email }
  end
end
