# frozen_string_literal: true
require File.join(File.dirname(__FILE__), '../app/workers/direct_serve_worker')

module Rack
  module Serve
    include Common

    def direct_serve_call
      error = verify_direct_serve_input
      return error if error&.any?

      set_direct_serve_params

      # Get surveys
      surveys = get_surveys_direct(@identifier, @udid, @client_key, @preview_mode, @custom_data)

      # No surveys to serve
      if surveys.empty?
        log 'No survey to serve'
        log_time
        return [200, {'Content-Type' => 'application/json'}, ['{}']]
      end

      # Survey(s) found, choose one randomly
      survey = surveys.sample

      log_time_influxdb(@env['REQUEST_PATH'], 'pi_surveys')

      device_data = get_device_data(@udid, @identifier)

      # Can return nil, in that case the ServeWorker will create the device
      device_id = get_device_id(@udid)

      # Fetch the survey in the database and return all questions and possible answers
      questions_and_possible_answers = load_survey_questions_and_possible_answers(@identifier, survey[:id])

      DirectServeWorker.perform_async(survey[:id], @submission_udid, device_id, @udid, @custom_data, @client_key)

      response = {
        survey: survey,
        questions_and_possible_answers: questions_and_possible_answers,
        submission: { udid: @submission_udid },
        device: { udid: @udid, client_key: @client_key },
        device_data: device_data
      }

      log "Serving survey id #{survey[:id]}"
      log survey.inspect, "DEBUG"
      log_time

      [200, response_header, [response.to_json]]
    end

    private

    def response_header
      { 'Content-Type' => 'text_plain' }
    end

    def set_direct_serve_params
      @identifier   = @params['identifier']
      @client_key   = valid_client_key?(@params['client_key']) ? @params['client_key'] : nil
      @udid         = @params['udid'] || SecureRandom.uuid
      @custom_data  = @params['custom_data']
      @submission_udid = SecureRandom.uuid
      @preview_mode = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')
      @ip_address = @env['HTTP_X_REAL_IP']
    end

    def verify_direct_serve_input
      required_params = %w(identifier)

      error = verify_required_params(required_params)
      return error if error

      # > For now, those are the same rules for the generic get survey and custom-fired present surveys.
      #   I wonder if we really need udid checking for custom firing present surveys
      if (@params['udid'].nil? || @params['udid'].strip.empty?) &&
         (@params['client_key'].nil? || @params['client_key'].strip.empty?)
        error = "Error: Parameter 'udid' or 'client_key' is missing"
        log error
        return [400, {'Content-Type' => 'text/plain'}, [error]]
      end

      error = verify_identifier
      return error unless error.empty?

      error = verify_account(@params['identifier'], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message
    end
  end
end
