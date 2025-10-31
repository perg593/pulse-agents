# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

# This worker will perform the following tasks:
# - Update 'account calls count' and 'last call at'
# - Create 'device' if needed
# - Create impression

class NativeServeWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common
  def perform(params)
    udid        = params['udid']
    device_id   = params['device_id']
    client_key  = params['client_key']

    device =
      if device_id
        UpdateClientKeyWorker.new.perform(device_id, client_key) if client_key
        { id: device_id.to_i, udid: udid, client_key: client_key }
      else
        CreateDeviceWorker.new.perform(udid, client_key)
      end

    NativeCreateImpressionWorker.new.perform(params, device)
  end
end
