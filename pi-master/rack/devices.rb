# frozen_string_literal: true
require File.join(File.dirname(__FILE__), '../app/workers/set_device_data_worker')

module Rack
  module Devices
    def device_set_data
      error = verify_identifier
      return error if error.present?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      @env['REQUEST_PATH'] =~ /\/devices\/([-a-zA-Z0-9]+)\/set_data/
      udid = Regexp.last_match(1)

      SetDeviceDataWorker.perform_async(udid, @params.reject { |param| ['callback'].include? param })

      log_time
      jsonp_response(@params["callback"], "{}")
    end
  end
end
