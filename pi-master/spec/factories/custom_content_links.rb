# frozen_string_literal: true

FactoryBot.define do
  factory :custom_content_link do
    custom_content_question
    link_identifier { SecureRandom.uuid }
    link_text { FFaker::Lorem.sentence }
    link_url { FFaker::Internet.http_url }
    report_color { "##{FFaker::Color.hex_code}" }
  end
end
