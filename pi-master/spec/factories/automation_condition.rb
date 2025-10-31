# frozen_string_literal: true

FactoryBot.define do
  factory :automation_condition do
    condition { "condition" }
    # automation
  end
end

# == Schema Information
#
# Table name: automation_conditions
#
#  id                  :integer          not null, primary key
#  automation_id :integer
#  question_id         :integer
#  condition           :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
