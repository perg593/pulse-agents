# frozen_string_literal: true
module Rack
  module PresentSurvey
    include Common

    # Custom firing survey call
    def present_survey_call
      set_present_survey_params

      error = verify_present_survey_params
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      @request_path =~ /^\/surveys\/([0-9]+)/
      @id = Regexp.last_match(1).to_i

      # Get survey by ID
      survey = get_survey_by_id(@id, @identifier, @udid, @device_type, @mobile_type)

      log_time_influxdb(@env['REQUEST_PATH'], 'pi_surveys')

      device_data = get_device_data(@udid, @identifier)

      # can return nil, in that case the ServeWorker will create the device
      device_id = get_device_id(@udid)

      submission_udid = SecureRandom.uuid

      if @device_type == 'native_mobile'
        NativeServeWorker.perform_async(present_native_serve_worker_params(survey[:id], submission_udid, device_id))
      else
        ServeWorker.perform_async(present_serve_worker_params(survey[:id], submission_udid, device_id))
      end

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

    def present_serve_worker_params(survey_id, submission_udid, device_id)
      serve_worker_base_params(survey_id, submission_udid, device_id).merge(
        'identifier' => @identifier,
        'url' => @url,
        'visit_count' => @visit_count,
        'pageview_count' => @pageview_count
      )
    end

    def present_native_serve_worker_params(survey_id, submission_udid, device_id)
      serve_worker_base_params(survey_id, submission_udid, device_id).merge(
        'identifier' => @identifier,
        'view_name' => @view_name,
        'launch_times' => @launch_times,
        'install_days' => @install_days,
        'mobile_type' => @mobile_type
      )
    end

    def verify_present_survey_params
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

      # Verify the id
      @request_path =~ /^\/surveys\/([0-9]+)/
      id = Regexp.last_match(1).to_i
      if id.zero?
        log "Invalid URL #{@request_path}"
        return [404, {'Content-Type' => 'text/plain'}, ['Not found']]
      end

      result = verify_account(@identifier, @callback)
      return result unless result.empty?

      []
    end

    def set_present_survey_params
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
      @client_key     = valid_client_key?(@params['client_key']) ? @params['client_key'] : nil

      @mobile_type    = @params['mobile_type']
      @view_name      = @params['view_name']
      @install_days   = @params['install_days'].nil? ? 0 : @params['install_days'].to_i
      @launch_times   = @params['launch_times'].nil? ? 0 : @params['launch_times'].to_i
    end
  end
end
