# frozen_string_literal: true

class SurveyTag < ActiveRecord::Base
  audited associated_with: :account

  belongs_to :account
  has_many :applied_survey_tags, dependent: :destroy

  validates :name, uniqueness: { scope: :account_id }
end

# == Schema Information
#
# Table name: survey_tags
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer
#
# Indexes
#
#  index_survey_tags_on_account_id  (account_id)
#
