# frozen_string_literal: true

FactoryBot.define do
  factory :page_after_seconds_trigger do
    render_after_x_seconds_enabled { true }
  end
end
