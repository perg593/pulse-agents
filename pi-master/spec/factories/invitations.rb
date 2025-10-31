# frozen_string_literal: true
FactoryBot.define do
  factory :invitation do
    email { "jeremy@pulseinsights.com" }
    level { 0 }
    token { SecureRandom.hex(10) }

    account
  end

  factory :reporting_only_invitation, class: 'Invitation' do
    email { "jeremy@pulseinsights.com" }
    level { 1 }
    token { SecureRandom.hex(10) }

    account
  end
end
