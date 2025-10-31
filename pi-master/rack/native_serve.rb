# frozen_string_literal: true
require File.join(File.dirname(__FILE__), '../app/workers/serve_worker')
require File.join(File.dirname(__FILE__), '../app/workers/native_serve_worker')

module Rack
  module NativeServe
    include Common

    def mobile_native_serve_call
      set_native_serve_params

      required_params = %w(identifier device_type udid)

      error = verify_required_params(required_params)
      return error if error

      error = verify_serve_params
      return error if error.any?

      error = verify_mobile_type(@params["mobile_type"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      # Get surveys
      surveys = get_surveys_for_native(@identifier, @udid, @preview_mode, @install_days, @launch_times, @client_key, @mobile_type, @view_name, @custom_data)

      # No surveys to serve
      if surveys.empty?
        log "No survey to serve"
        log_time
        return json_response(["{}"])
      end

      # Survey(s) found, choose one randomly
      survey = surveys.sample

      log_time_influxdb(@env['REQUEST_PATH'], 'pi_surveys')

      device_data = get_device_data(@udid, @identifier)

      # can return nil, in that case the ServeWorker will create the device
      device_id = get_device_id(@udid)

      submission_udid = SecureRandom.uuid

      NativeServeWorker.perform_async(native_serve_worker_params(survey[:id], submission_udid, device_id))

      response = { survey: survey, submission: { udid: submission_udid }, device: { udid: @udid }, device_data: device_data }

      log "Serving survey id #{survey[:id]}"
      log survey.inspect, "DEBUG"
      log_time

      json_response([JSON.dump(response)])
    end

    private

    def native_serve_worker_params(survey_id, submission_udid, device_id)
      serve_worker_base_params(survey_id, submission_udid, device_id).merge(
        'view_name' => @view_name,
        'launch_times' => @launch_times,
        'install_days' => @install_days,
        'mobile_type' => @mobile_type
      )
    end

    def set_native_serve_params
      @identifier     = @params['identifier']
      @udid           = @params['udid']
      @preview_mode   = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')
      @install_days   = @params['install_days'].nil? ? 0 : @params['install_days'].to_i
      @launch_times   = @params['launch_times'].nil? ? 0 : @params['launch_times'].to_i
      @preview_mode   = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')
      @view_name      = @params['view_name']
      @custom_data    = @params['custom_data']
      @ip_address     = @env['HTTP_X_REAL_IP']
      @user_agent     = @env['HTTP_USER_AGENT']
      @country        = @env['HTTP_GEOIP_COUNTRY_NAME'] || ''
      @state          = @env['HTTP_GEOIP_STATE_NAME'] || ''
      @metro_code     = @env['HTTP_GEOIP_DATA_METRO_CODE'].nil? ? '' : @env['HTTP_GEOIP_DATA_METRO_CODE'].to_s
      @client_key     = valid_client_key?(@params['client_key']) ? @params['client_key'] : nil
      @mobile_type    = @params['mobile_type']
    end
  end
end
