# frozen_string_literal: true

FactoryBot.define do
  factory :successful_mfa_signin do
    user
    ip_address { "192.168.1.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
  end
end
