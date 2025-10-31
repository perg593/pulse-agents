# frozen_string_literal: true

class PromptTemplate < ApplicationRecord
  audited

  validates :name, presence: true, uniqueness: true
  validates :content, presence: true

  scope :default, -> { where(is_default: true) }

  before_save :ensure_single_default

  private

  def ensure_single_default
    return unless is_default?

    # If this template is being set as default, unset any other defaults
    self.class.where(is_default: true).where.not(id: id).update_all(is_default: false)
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
