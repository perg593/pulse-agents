# frozen_string_literal: true
FactoryBot.define do
  factory :worker_output_copy do
    file_name { "#{FFaker::Lorem.word}.csv" }
  end
end
