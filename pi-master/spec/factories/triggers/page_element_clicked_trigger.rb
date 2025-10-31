# frozen_string_literal: true

FactoryBot.define do
  factory :page_element_clicked_trigger do
    render_after_element_clicked_enabled { true }
  end
end
