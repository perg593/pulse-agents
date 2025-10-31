# frozen_string_literal: true
class Invitation < ActiveRecord::Base
  audited associated_with: :account

  belongs_to :account

  validates :email, presence: true
  validates :email, email: true
  validate :email_does_not_belong_to_user
  validates :level, acceptance: { accept: User.levels.values }
  validates :level, presence: true

  before_create :set_expiry, :set_token

  def self.pick_a_valid_token
    loop do
      token = SecureRandom.hex(10)
      return token unless Invitation.default_scoped.exists?(token: token)
    end
  end

  def invite_new_user_to_account
    UserMailer.send_out_invitation(self).deliver_now
  end

  def expired?
    expires_at < Time.current
  end

  private

  def set_expiry
    return if expires_at.present?

    self.expires_at = 1.month.from_now
  end

  def set_token
    self.token = Invitation.pick_a_valid_token
  end

  def email_does_not_belong_to_user
    errors.add(:email, "A user with this email already exists, please try another email address") if User.exists?(email: email)
  end
end

# == Schema Information
#
# Table name: invitations
#
#  id         :integer          not null, primary key
#  email      :string(255)
#  expires_at :datetime
#  level      :integer          default(0)
#  token      :string(255)
#  created_at :datetime
#  updated_at :datetime
#  account_id :integer
#
# Indexes
#
#  index_invitations_on_account_id  (account_id)
#  index_invitations_on_email       (email)
#  index_invitations_on_token       (token)
#
