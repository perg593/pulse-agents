# frozen_string_literal: true
module Inviteable
  extend ActiveSupport::Concern

  included do
    # `invite_email` is the email address that user want to invite.
    # Inviter will send invitation to this email
    attr_accessor :invite_email

    # `invite_token` belongs to the user who was invited,
    # Used for link to one account, and estimate that create account or not
    attr_accessor :invite_token

    has_one :invitation, through: :account

    after_create :remove_invitation, if: :from_invitation?
    before_validation :link_to_account_for_invite_user, if: :from_invitation?
    before_validation :set_level, if: :from_invitation?

    validate :invitation_not_expired
  end

  private

  def invitation_not_expired
    errors.add(:invitation, "is expired") if invitation&.expired?
  end

  def remove_invitation
    Invitation.where(token: invite_token).destroy_all
    true
  end

  def link_to_account_for_invite_user
    self.account_id = Account.joins(:invitation).where(invitations: {token: invite_token}).first.try(:id)
    true
  end

  def set_level
    self.level = invitation.level if invitation
    true
  end

  def from_invitation?
    invite_token.present? && Invitation.exists?(token: invite_token)
  end

  def invitation
    Invitation.where(token: invite_token).first
  end
end
