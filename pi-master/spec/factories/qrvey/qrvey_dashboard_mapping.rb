# frozen_string_literal: true
FactoryBot.define do
  factory :qrvey_dashboard_mapping do
    qrvey_name { FFaker::Lorem.unique.sentence }
    pi_name { FFaker::Lorem.unique.sentence }
    position { 1 }
  end
end
