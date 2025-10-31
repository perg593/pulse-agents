# Be sure to restart your server when you modify this file.

require 'sidekiq/web'

Rails.application.config.session_store :active_record_store, :key => '_pi_session'
