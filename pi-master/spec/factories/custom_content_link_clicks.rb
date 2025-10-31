# frozen_string_literal: true
FactoryBot.define do
  factory :custom_content_link_click do
    submission
    client_key { '' }
    custom_data { nil }
    custom_content_link
  end
end
