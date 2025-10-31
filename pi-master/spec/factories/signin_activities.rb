# frozen_string_literal: true

FactoryBot.define do
  factory :signin_activity do
    sudoer { nil }
    account
    user
  end
end
