# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class CreatePageEventWorker
  include Sidekiq::Worker
  include Common

  def perform(event_name, event_properties, identifier, udid, url)
    tagged_logger.info 'Started'
    tagged_logger.error "Account not found #{identifier}" and return unless account = Account.find_by(identifier: identifier)

    device = Device.find_or_create_by(udid: udid)

    PageEvent.create!(name: event_name, properties: event_properties, account: account, device: device, url: url)
  rescue => e
    tagged_logger.error e
    Rollbar.error e
  ensure
    tagged_logger.info 'Finished'
  end
end
