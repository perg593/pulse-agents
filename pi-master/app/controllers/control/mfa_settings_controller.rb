# frozen_string_literal: true
module Control
  class MFASettingsController < BaseController
    def new
      redirect_back fallback_location: edit_my_account_path, notice: "MFA already set up" and return if current_user.otp_required_for_login?

      return if current_user.otp_secret.present?

      current_user.update(otp_secret: User.generate_otp_secret)
    end

    def edit
      redirect_to new_mfa_settings_path and return unless current_user.otp_required_for_login?

      @unencrypted_backup_codes = current_user.generate_otp_backup_codes!
      current_user.save!

      flash[:notice] = "Successfully enabled multi-factor authentication, please store your backup codes securely."
    end

    def create
      redirect_back fallback_location: edit_my_account_path and return if current_user.otp_required_for_login?

      if current_user.valid_password?(params[:password]) && current_user.validate_and_consume_otp!(params[:code])
        current_user.activate_mfa!
      else
        flash.alert = "Incorrect Password or Code"
      end

      redirect_to edit_mfa_settings_path
    end

    def destroy
      current_user.deactivate_mfa!

      redirect_back fallback_location: edit_my_account_path, notice: "MFA deactivated."
    end
  end
end
