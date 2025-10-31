# frozen_string_literal: true

FactoryBot.define do
  factory :url_matches_trigger do
    url_matches { "www.pulseinsights.com" }
  end
end
