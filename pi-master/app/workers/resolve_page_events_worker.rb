# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class ResolvePageEventsWorker
  include Sidekiq::Worker
  include Common

  def perform(identifier, udid, url)
    tagged_logger.info 'Started'
    tagged_logger.error "Account not found #{identifier}" and return unless account = Account.find_by(identifier: identifier)

    device = Device.find_or_create_by(udid: udid)

    automations = account.automations.enabled.where(condition_type: :url)
    automations.each do |automation|
      next unless automation.url_condition.url_meets_condition?(url)
      event_name, event_properties = automation.actions.pick(:event_name, :event_properties)
      PageEvent.create!(name: event_name, properties: event_properties, account: account, device: device, url: url)
      automation.update_trigger_stats
    end
  rescue => e
    tagged_logger.error e
    Rollbar.error e
  ensure
    tagged_logger.info 'Finished'
  end
end
