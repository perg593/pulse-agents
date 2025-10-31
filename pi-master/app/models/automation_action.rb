# frozen_string_literal: true

class AutomationAction < ActiveRecord::Base
  audited associated_with: :automation

  belongs_to :automation
end

# == Schema Information
#
# Table name: automation_actions
#
#  id               :integer          not null, primary key
#  email            :string
#  event_name       :string
#  event_properties :jsonb
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  automation_id    :integer
#
# Indexes
#
#  index_automation_actions_on_automation_id  (automation_id)
#
