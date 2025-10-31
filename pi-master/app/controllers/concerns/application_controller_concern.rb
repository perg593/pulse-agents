# frozen_string_literal: true

module ApplicationControllerConcern
  extend ActiveSupport::Concern

  include Authorization

  included do
    protect_from_forgery with: :exception

    delegate :url_helpers, to: 'Rails.application.routes'
    delegate :helpers, to: 'ActionController::Base'

    before_action :update_last_action_date

    def update_last_action_date
      return if Rails.env.development? || !current_user

      last_action_date = current_user.last_action_at
      current_user.update(last_action_at: Time.current)

      return unless last_action_date.present? && last_action_date <= 30.minutes.ago

      session.delete(:sudo_from_id)
      warden.logout
      redirect_to after_logout_url, alert: "Logged out due to inactivity."
    end
  end
end
