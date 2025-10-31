# frozen_string_literal: true

FactoryBot.define do
  factory :regexp_trigger do
    regexp { "abc.*" }
  end
end
