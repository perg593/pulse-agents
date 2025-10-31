# frozen_string_literal: true

require File.join(File.dirname(__FILE__), '../app/workers/create_page_event_worker')

module Rack
  module TrackEvent
    include Common

    def track_event
      required_params = %w(event_name event_properties identifier)

      error = verify_required_params(required_params)
      return error if error

      error = verify_identifier
      error = verify_udid if error.empty?
      error = verify_event_params if error.empty?
      return error unless error.empty?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      CreatePageEventWorker.perform_async(@params['event_name'], @params['event_properties'], @params['identifier'], @params['udid'], @params['url'])

      jsonp_response @params['callback'], '{}'
    end

    def verify_event_params
      error =
        if @params['event_name'].nil? || @params['event_name'].empty?
          "Error: Parameter 'event_name' blank"
        elsif @params['event_properties'].nil? || @params['event_properties'].empty?
          "Error: Parameter 'event_properties' blank"
        elsif @params['url'].nil? || @params['url'].empty?
          "Error: URL not captured"
        end

      return [] unless error
      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end
  end
end
