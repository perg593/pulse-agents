# frozen_string_literal: true
FactoryBot.define do
  factory :prompt_template do
    sequence(:name) { |i| "Prompt Template #{i}" }
    content { "This is a test prompt template content." }
    is_default { false }

    trait :default do
      is_default { true }
    end
  end
end

# == Schema Information
#
# Table name: prompt_templates
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  content    :text             not null
#  is_default :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_prompt_templates_on_is_default  (is_default)
#  index_prompt_templates_on_name        (name) UNIQUE
#
