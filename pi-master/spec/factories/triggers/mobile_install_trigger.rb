# frozen_string_literal: true

FactoryBot.define do
  factory :mobile_install_trigger do
    mobile_days_installed { 3 }
  end
end
