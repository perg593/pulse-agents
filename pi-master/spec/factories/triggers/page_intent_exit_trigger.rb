# frozen_string_literal: true

FactoryBot.define do
  factory :page_intent_exit_trigger do
    render_after_intent_exit_enabled { true }
  end
end
