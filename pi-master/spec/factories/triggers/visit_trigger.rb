# frozen_string_literal: true

FactoryBot.define do
  factory :visit_trigger do
    visitor_type { :all_visitors }
    visits_count { 1 }
  end
end
