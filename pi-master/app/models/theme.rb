# frozen_string_literal: true

class Theme < ActiveRecord::Base
  audited

  belongs_to :account
  has_many :surveys

  validates_presence_of :name
  validates :native_content, json: true, if: -> { native? }

  before_save :parse_native_content, if: -> { native? }

  enum theme_type: { css: 0, native: 1 }

  private

  # It doesn't reach here if a string is unparsable: app/model/validators/json_validator.rb
  def parse_native_content
    return unless native_content.is_a?(String)
    self.native_content = JSON.parse(native_content)
  end
end

# == Schema Information
#
# Table name: themes
#
#  id             :integer          not null, primary key
#  css            :text
#  name           :string
#  native_content :json
#  theme_type     :integer          default("css"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_themes_on_account_id  (account_id)
#
