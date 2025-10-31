# frozen_string_literal: true

FactoryBot.define do
  factory :page_element_visible_trigger do
    render_after_element_visible_enabled { true }
  end
end
