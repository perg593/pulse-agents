# frozen_string_literal: true
FactoryBot.define do
  factory :automation do
    name { "My awesome automation" }
    enabled { true }
    condition_type { Automation.condition_types['answer_text'] }
    action_type { Automation.action_types['send_email'] }
    trigger_type { Automation.trigger_types['all_conditions'] }

    account

    factory :automation_with_condition do
      conditions { build_list(:automation_condition, 1) }
    end

    factory :automation_with_action do
      actions { build_list(:automation_action, 1) }
    end

    factory :automation_with_condition_and_action do
      conditions { build_list(:automation_condition, 1) }
      actions { build_list(:automation_action, 1) }
    end
  end

  factory :automation_without_account do
    name { "My awesome automation" }
    enabled { true }
    condition_type { Automation.condition_types['submission'] }
    action_type { Automation.action_types['send_email'] }
    trigger_type { Automation.trigger_types['all_conditions'] }
  end
end

# == Schema Information
#
# Table name: automations
#
#  id                :integer          not null, primary key
#  action_type       :integer          default("send_email"), not null
#  condition_type    :integer          default("submission"), not null
#  enabled           :boolean          default(FALSE)
#  last_triggered_at :datetime
#  name              :string
#  times_triggered   :integer
#  trigger_type      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer
#
# Indexes
#
#  index_automations_on_account_id  (account_id)
#
