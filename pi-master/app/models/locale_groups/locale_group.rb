# frozen_string_literal: true

class LocaleGroup < ActiveRecord::Base
  before_create :ensure_unique_name

  # overridden by subclasses
  def find_account; end

  private

  def ensure_unique_name
    return unless LocaleGroup.find_by(type: type, owner_record_id: owner_record_id, name: name)

    self.name = "#{name}_#{LocaleGroup.last.id + 1}"
  end
end

# == Schema Information
#
# Table name: locale_groups
#
#  id              :bigint           not null, primary key
#  name            :string
#  report_color    :string
#  type            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  owner_record_id :integer
#
# Indexes
#
#  index_locale_groups_on_owner_record_id                    (owner_record_id)
#  index_locale_groups_on_type_and_owner_record_id           (type,owner_record_id)
#  index_locale_groups_on_type_and_owner_record_id_and_name  (type,owner_record_id,name) UNIQUE
#
