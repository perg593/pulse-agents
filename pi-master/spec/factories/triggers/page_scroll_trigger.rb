# frozen_string_literal: true

FactoryBot.define do
  factory :page_scroll_trigger do
    render_after_x_percent_scroll_enabled { true }
  end
end
