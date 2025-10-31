# frozen_string_literal: true

class TrimSessionsWorker
  include Sidekiq::Worker

  # This will delete all sessions that have not been updated in the last 30 days.
  # https://github.com/rails/activerecord-session_store
  def perform
    cutoff_period = 30.days.ago

    ActiveRecord::SessionStore::Session.where("updated_at < ?", cutoff_period).delete_all
  end
end
