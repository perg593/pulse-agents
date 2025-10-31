# frozen_string_literal: true
module Control
  class UsersController < BaseController
    def switch_accounts
      new_account_id = params[:account_id]

      current_user.switch_accounts(new_account_id)

      if current_user.errors.blank?
        flash.alert = "Switched to #{current_user.account.autocomplete_name}"
      end

      redirect_to after_sign_in_url
    end
  end
end
