# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

# This worker will perform the following tasks:
# - Update 'account calls count' and 'last call at'
# - Create 'device' if needed
# - Create impression

class DirectServeWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(survey_id, submission_udid, device_id, udid, custom_data, client_key)
    if device_id
      device = { id: device_id.to_i }
      UpdateClientKeyWorker.perform_async(device_id, client_key) if client_key
    else
      device = CreateDeviceWorker.new.perform(udid, client_key)
    end

    CreateImpressionWorker.new.perform(
      'survey_id' => survey_id,
      'udid' => submission_udid,
      'device' => device,
      'custom_data' => custom_data,
      'client_key' => client_key
    )
  end
end
