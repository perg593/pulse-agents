# frozen_string_literal: true
require File.join(File.dirname(__FILE__), '../app/workers/serve_worker')
require File.join(File.dirname(__FILE__), '../app/workers/resolve_page_events_worker')

module Rack
  module Serve
    include Common

    # Main serve call - first call initiated by every page that includes the tag
    # If native mobile we call #mobile_native_serve_call, otherwise #main_serve_call
    def serve_call
      required_params = %w(identifier device_type)

      error = verify_required_params(required_params)
      return error if error

      set_serve_params

      # Verify device_type
      unless (result = verify_get_survey_params).empty?
        return result
      end

      case @params['device_type']
      when 'native_mobile'
        mobile_native_serve_call
      when 'email'
        email_serve_call
      else
        main_serve_call
      end
    end

    def main_serve_call
      # Verify all the parameters
      error = verify_serve_params
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      ResolvePageEventsWorker.perform_async(@identifier, @udid, @url) if url_type_automation_exists?(@identifier)

      # Get surveys
      surveys = get_surveys(@identifier, @url, @udid, @client_key, @device_type, @preview_mode, @pageview_count, @visit_count, @custom_data)
      return surveys if surveys.is_a?(Array) && surveys[0] == 403 # invalid url
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
      ServeWorker.perform_async(serve_worker_params(survey[:id], submission_udid, device_id))

      log "Serving survey id #{survey[:id]}"
      log survey.inspect, "DEBUG"
      log_time

      jsonp_response(@callback, JSON.dump(survey: survey, submission: { udid: submission_udid }, device: { udid: @udid }, device_data: device_data))
    end

    private

    def serve_worker_params(survey_id, submission_udid, device_id)
      serve_worker_base_params(survey_id, submission_udid, device_id).merge(
        {
          'url' => @url,
          'visit_count' => @visit_count,
          'pageview_count' => @pageview_count
        }
      )
    end

    def set_serve_params
      @identifier      = @params['identifier']
      @callback        = @params['callback']
      @udid            = @params['udid']
      @client_key      = valid_client_key?(@params['client_key']) ? @params['client_key'] : nil
      @device_type     = @params['device_type']
      @pageview_count  = @params['pageview_count'].nil? ? 0 : @params['pageview_count'].to_i
      @visit_count     = @params['visit_count'].nil? ? 0 : @params['visit_count'].to_i
      @preview_mode    = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')
      @custom_data     = @params['custom_data']

      begin
        @custom_data = @custom_data.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      rescue StandardError => e
        @custom_data = '{}'
      end

      @url             = @params['url'] || @env['HTTP_REFERER']
      @ip_address      = @env['HTTP_X_REAL_IP']
      @user_agent      = @env['HTTP_USER_AGENT']
      @country         = @env['HTTP_GEOIP_COUNTRY_NAME'] || ''
      @state           = @env['HTTP_GEOIP_STATE_NAME'] || ''
      @metro_code      = @env['HTTP_GEOIP_DATA_METRO_CODE'].nil? ? '' : @env['HTTP_GEOIP_DATA_METRO_CODE'].to_s
    end
  end
end
