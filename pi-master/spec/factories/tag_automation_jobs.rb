# frozen_string_literal: true
FactoryBot.define do
  factory :tag_automation_job do
    status { :in_progress }
    question
  end
end
