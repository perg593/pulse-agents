# frozen_string_literal: true
module Auth
  class EmailsController < ApplicationController
    layout 'auth'

    def edit
      @user = User.new(email: params[:new_email], reset_email_token: params[:reset_email_token])
    end

    def update
      user = User.find_by(reset_email_token: params[:user][:reset_email_token])
      redirect_to sign_in_url, alert: "Sorry, couldn't find your user" and return unless user
      redirect_to sign_in_url, alert: "Sorry, couldn't verify you" and return unless user.valid_password?(params[:user][:password])
      redirect_to sign_in_url, alert: "Sorry, the confirmation email has expired" and return if user.reset_email_token_expired?
      redirect_to sign_in_url, alert: "Sorry, failed to update your email" and return unless user.update(email: params[:user][:new_email])

      # Logging the user out because email is part of the sign-in credentials paired with password.
      # It'd be ideal to serialize it into sessions like we do for password, but it's advised that you keep the serialized object simple.
      warden&.logout
      redirect_to sign_in_url, notice: 'Email successfully updated!'
    end
  end
end
