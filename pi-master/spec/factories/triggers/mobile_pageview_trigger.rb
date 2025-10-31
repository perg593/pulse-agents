# frozen_string_literal: true

FactoryBot.define do
  factory :mobile_pageview_trigger do
    mobile_pageview { "some_page" }
  end
end
