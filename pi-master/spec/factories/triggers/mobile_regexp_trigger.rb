# frozen_string_literal: true

FactoryBot.define do
  factory :mobile_regexp_trigger do
    mobile_regexp { "abc.*" }
  end
end
