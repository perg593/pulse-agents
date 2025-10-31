# frozen_string_literal: true

FactoryBot.define do
  factory :page_event do
    name { FFaker::Lorem.word }
    properties { { test: 1}.to_json }
    device
    account
    url { FFaker::Internet.http_url }
  end
end
