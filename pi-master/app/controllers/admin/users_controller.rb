# frozen_string_literal: true
module Admin
  class UsersController < ApplicationController
    layout 'control'
    before_action :require_admin!, except: [:destroy]
    before_action :require_full_access_user!, only: [:destroy]
    before_action :set_user, only: %i(activate deactivate)

    def index
      @objects = User.search(params[:keyword])

      render 'admin/accounts/index'
    end

    # Used by the user level dropdown
    def update
      @user = User.find(params[:id])
      if @user == current_user
        respond_to do |format|
          format.json { render json: :forbidden, status: 403 }
        end
      else
        @user.update(level: params[:user][:level].to_i)
        respond_to do |format|
          format.json { render json: :ok }
        end
      end
    rescue ActiveRecord::RecordNotFound => e
      respond_to do |format|
        format.json { render json: :not_found, status: 404 }
      end
    end

    def destroy
      return redirect_to(request.referer, notice: 'You cannot delete yourself.') if current_user.id == params[:id].to_i
      @user = User.find(params[:id])
      @user.destroy

      if @user.destroyed?
        redirect_back fallback_location: root_path, notice: 'User was successfully destroyed.'
      else
        redirect_back fallback_location: root_path, notice: "Error deleting #{@user.name}: #{@user.errors.full_messages.join(". ")}"
      end
    end

    def login_as
      user = User.find(params[:id])
      session[:sudo_from_id] = current_user.id
      SigninActivity.create(account: user.account, user: user, sudoer: current_user)
      warden.set_user(user)
      user.update(last_action_at: Time.current)
      name = user.name.presence || user.email
      flash.alert = "Successfully logged in as #{name}"
      redirect_to after_sign_in_url
    end

    def activate
      if @user == current_user
        redirect_to admin_users_path, flash: { alert: 'You cannot activate yourself!' }
      else
        @user.update active: true, last_sign_in_at: Time.current
        redirect_to admin_users_path, flash: { notice: "You have activated #{@user.email} successfully!" }
      end
    end

    def deactivate
      if @user == current_user
        redirect_to admin_users_path, flash: { alert: 'You cannot deactivate yourself!' }
      else
        @user.update active: false
        redirect_to admin_users_path, flash: { notice: "You have deactivated #{@user.email} successfully!" }
      end
    end

    def add_account_link
      # parsing Account.autocomplete_name for unique identifier
      account_identifier = /#{Account::IDENTIFIER_PREFIX}[^)]*/.match(params[:account_name]).to_s

      account = Account.find_by(identifier: account_identifier)
      user = User.find_by(id: params[:id])

      begin
        AccountUser.create(account_id: account.id, user_id: user.id)
        render json: { tags: user.autocomplete_tags, url: remove_account_link_admin_user_url(account_id: account.id, user_id: user.id)}, status: :ok
      rescue ActiveRecord::RecordNotUnique
        render json: {}, status: :bad_request
      end
    end

    def remove_account_link
      AccountUser.find_by(account_id: params[:account_id], user_id: params[:id]).destroy

      user = User.find_by(id: params[:id])

      render json: user&.autocomplete_tags, status: :ok
    end

    private

    def set_user
      @user = User.find_by id: params[:id]
      redirect_to dashboard_path and return unless @user
    end
  end
end
