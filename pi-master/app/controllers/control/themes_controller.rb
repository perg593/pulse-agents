# frozen_string_literal: true
module Control
  class ThemesController < BaseController
    before_action :set_theme, only: %i(destroy edit show update)
    before_action :deny_unauthorized_user, only: %i(show edit update destroy)

    def index
      @user = current_user
      @themes = Theme.where(account: current_account).order('name ASC')

      @audits = current_account.associated_audits.where(auditable_type: "Theme") if current_user.admin?
    end

    def new
      @theme = Theme.new
    end

    def show
      @audits = @theme.audits.descending if current_user.admin?
    end

    def edit
      @audits = @theme.audits.descending if current_user.admin?
    end

    def create
      @theme = Theme.new(theme_params.merge(account: current_account))

      if @theme.save
        flash[:notice] = 'Theme was successfully created.'
        redirect_to themes_path
      else
        flash.now.alert = @theme.errors.full_messages.join(',')
        render :new
      end
    end

    def update
      if @theme.update(theme_params)
        flash.now.notice = 'Theme was successfully updated.'
      else
        flash.now.alert = @theme.errors.full_messages.join(',')
      end

      render :edit
    end

    def destroy
      if @theme.delete
        flash[:notice] = 'Theme was successfully destroyed.'
      else
        flash[:alert] = @theme.errors.full_messages.join(',')
      end

      redirect_to themes_path
    end

    private

    def deny_unauthorized_user
      redirect_to themes_path if @theme.account != current_account
    end

    def set_theme
      @theme = Theme.find_by(id: params[:id])

      redirect_to dashboard_path and return unless @theme
    end

    def theme_params
      params.require(:theme).permit(:name, :theme_type, :css, :native_content)
    end
  end
end
