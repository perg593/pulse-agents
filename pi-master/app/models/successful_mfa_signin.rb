# frozen_string_literal: true

class SuccessfulMFASignin < ApplicationRecord
  belongs_to :user

  validates :ip_address, presence: true

  scope :recent, ->(time_limit = 1.month.ago) { where("created_at > ?", time_limit) }
  scope :matching_fingerprint, ->(ip_address, user_agent) { where(ip_address: ip_address, user_agent: user_agent) }
end

# == Schema Information
#
# Table name: successful_mfa_signins
#
#  id         :bigint           not null, primary key
#  ip_address :inet
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_successful_mfa_signins_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
