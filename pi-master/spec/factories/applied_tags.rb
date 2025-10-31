# frozen_string_literal: true
FactoryBot.define do
  factory :applied_tag do
    answer
    tag
  end

  factory :automatically_applied_tag, class: 'AppliedTag' do
    answer
    tag
    tag_automation_job
    is_good_automation { false }
  end
end
