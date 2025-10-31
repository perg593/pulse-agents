# frozen_string_literal: true
require File.join(File.dirname(__FILE__), '../app/workers/serve_worker')
require File.join(File.dirname(__FILE__), '../app/workers/native_serve_worker')

module Rack
  module PresentEvent
    include Common

    # Custom firing survey call
    def present_event_call
      set_present_event_params

      error = verify_present_event_params
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      @request_path =~ /^\/surveys\/([-a-zA-Z0-9]+)/
      @pseudo_event = Regexp.last_match(1).to_s
      # Get survey by EVENT NAME
      surveys = get_surveys_by_event_name(@pseudo_event, @identifier, @udid, @device_type)

      # No surveys to serve
      if surveys.empty?
        log "No survey to serve"
        log_time
        return jsonp_response(@callback, "{}")
      end

      # Survey(s) found, choose one randomly
      survey = surveys.sample

      log_time_influxdb(@env['REQUEST_PATH'], 'pi_surveys')

      device_data = get_device_data(@udid, @identifier)

      # can return nil, in that case the ServeWorker will create the device
      device_id = get_device_id(@udid)

      submission_udid = SecureRandom.uuid

      ServeWorker.perform_async(present_event_worker_params(survey[:id], submission_udid, device_id))

      response = { survey: survey,
                   submission: { udid: submission_udid },
                   device: { udid: @udid },
                   device_data: device_data }

      log "Presenting survey id #{survey[:id]}"
      log_time

      log response

      jsonp_response(@callback, JSON.dump(response))
    end

    private

    def present_event_worker_params(survey_id, submission_udid, device_id)
      {
        'identifier' => @identifier,
        'survey_id' => survey_id,
        'submission_udid' => submission_udid,
        'device_id' => device_id,
        'udid' => @udid,
        'url' => @url,
        'ip_address' => @ip_address,
        'user_agent' => @user_agent,
        'custom_data' => @custom_data,
        'device_type' => @device_type,
        'visit_count' => @visit_count,
        'pageview_count' => @pageview_count,
        'pseudo_event' => @pseudo_event
      }
    end

    def verify_present_event_params
      # Verify all the parameters
      unless (result = verify_get_survey_params).empty?
        return result
      end

      # URL here is only necessary to create the impression
      # no triggering rules evaluated in this call
      if @url.nil? && @device_type != 'native_mobile'
        error = 'Error: HTTP_REFERER or url param missing'
        log error
        return [400, {'Content-Type' => 'text/plain'}, [error]]
      end

      # Verify the event name
      @request_path =~ /^\/surveys\/([-a-zA-Z0-9]+)/
      @pseudo_event = Regexp.last_match(1).to_s
      if @pseudo_event.nil?
        log "Invalid URL #{@request_path}"
        return [404, {'Content-Type' => 'text/plain'}, ['Not found']]
      end

      verify_account(@identifier, @callback)
    end

    def set_present_event_params
      @identifier     = @params['identifier']
      @callback       = @params['callback']
      @udid           = @params['udid']
      @device_type    = @params['device_type']
      @ip_address     = @env['HTTP_X_REAL_IP']
      @user_agent     = @env['HTTP_USER_AGENT']
      @url            = @params['url'] || @env['HTTP_REFERER']
      @request_path   = @env['REQUEST_PATH']
      @custom_data    = @params['custom_data']
      @pageview_count = @params['pageview_count']&.to_i
      @visit_count    = @params['visit_count']&.to_i
      @preview_mode   = @params['preview_mode'] == 'true'
    end
  end
end
