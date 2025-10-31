# frozen_string_literal: true

FactoryBot.define do
  factory :automation_action do
    email { "admin@pi.com" }
    # automation
  end
end

# == Schema Information
#
# Table name: automation_actions
#
#  id                  :integer          not null, primary key
#  action               :string
#  event_name          :string
#  event_properties    :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  automation_id :integer
#
# Indexes
#
#  index_automation_actions_on_automation_id  (automation_id)
#
