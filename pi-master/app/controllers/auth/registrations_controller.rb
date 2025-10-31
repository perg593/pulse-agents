# frozen_string_literal: true
module Auth
  class RegistrationsController < BaseController
    before_action :set_invitation, only: [:new]

    def new
      session[:from_invitation] = @invitation ? 'yes' : 'no'

      @user = if @invitation
        if @invitation.expired?
          redirect_to sign_in_url, flash: { alert: "Invitation expired" }
        else
          User.new(invite_token: @invitation.token,
                   email: @invitation.email,
                   account_id: @invitation.account_id)
        end
      else
        User.new
      end
    end

    def create
      @user = User.new(user_params)

      if @user.errors.empty? && @user.save
        warden.set_user(@user)
        redirect_to after_sign_in_url
      else
        p @user.errors
        render :new
      end
    end

    private

    def set_invitation
      @invitation = Invitation.find_by(token: params[:invite_token], email: params[:email])
    end

    def user_params
      params[:user][:email].downcase!

      params.require(:user).permit(
        :email, :first_name, :last_name, :password, :invite_token,
        {
          account_attributes: [
            :name
          ]
        }
      )
    end
  end
end
