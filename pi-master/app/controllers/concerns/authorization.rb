# frozen_string_literal: true
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :user_signed_in?
  end

  def warden
    request.env['warden']
  end

  def current_account
    current_user&.account
  end

  def after_sign_up_url
    sign_in_url
  end

  def after_sign_in_url
    dashboard_url
  end

  def after_logout_url
    root_url
  end

  def require_user!
    unless user_signed_in?
      render json: :unauthorized, status: 401 and return if request.xhr?

      flash.alert = 'You need to be logged in to access this page.'
      redirect_to sign_in_url
      return false
    end
  rescue ActiveRecord::RecordNotFound
    # Happens if a logged in user gets deleted from the database
    redirect_to sign_in_url
    return false
  end

  def require_logout!
    if user_signed_in?
      redirect_to after_sign_in_url
      return false
    end
  rescue ActiveRecord::RecordNotFound
    return false
  end

  def require_admin!
    if !user_signed_in?
      flash.alert = 'You need to be logged in to access this page.'
      redirect_to sign_in_url
      return false
    elsif !current_user.admin?
      flash.alert = 'Unauthorized!'
      redirect_to dashboard_url
      return false
    end
  rescue ActiveRecord::RecordNotFound
    # Happens if a logged in user gets deleted from the database
    redirect_to sign_in_url
    return false
  end

  def require_full_access_user!
    if !user_signed_in?
      flash.alert = 'You need to be logged in to access this page.'
      redirect_to sign_in_url
      return false
    elsif !current_user.full?
      flash.alert = 'Unauthorized!'
      redirect_to dashboard_url
      return false
    end
  rescue ActiveRecord::RecordNotFound
    # Happens if a logged in user gets deleted from the database
    redirect_to sign_in_url
    return false
  end
end
