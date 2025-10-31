# frozen_string_literal: true
class DeactivateExpiredUsersWorker
  include Sidekiq::Worker
  include Common

  OFFLINE_PERIOD = 6.months

  def perform
    tagged_logger.info "Started"

    expired_users = User.active.where("last_sign_in_at < ?", OFFLINE_PERIOD.ago).or(
      User.active.where("last_sign_in_at is NULL AND created_at < ?", OFFLINE_PERIOD.ago)
    )

    expired_users.find_each do |user|
      tagged_logger.info "Deactivating User ##{user.id}."

      user.password = User.random_password
      user.active = false
      user.save!(validate: false)

      tagged_logger.info "Deactivated User ##{user.id}."
    end
  rescue => e
    tagged_logger.error e
    Rollbar.error e
  ensure
    tagged_logger.info "Finished"
  end
end
