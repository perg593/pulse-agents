# frozen_string_literal: true
module Lockable
  extend ActiveSupport::Concern

  def valid_for_authentication?
    super && active? && persisted?
  end

  def lock_access!(opts = {})
    super

    ip_address = opts[:ip_address]

    # Prevent MFA bypass after unlock
    # The user must regain our trust
    successful_mfa_signins.destroy_all

    UserMailer.locked_notification(self, ip_address).deliver_now
  end
end
