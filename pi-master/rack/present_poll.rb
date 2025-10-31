# frozen_string_literal: true
module Rack
  module PresentPoll
    include Common

    # Custom firing survey call to present poll
    def present_poll_call
      set_present_poll_params

      error = verify_present_poll_params
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      @request_path =~ /^\/surveys\/([0-9]+)/
      @id = Regexp.last_match(1).to_i

      # Get survey by ID
      survey = get_survey_by_id(@id, @identifier, @udid, @device_type)

      unless get_poll_enabled(@id, @identifier)
        error = 'Error: Poll not enabled for this survey'
        log error
        return [403, {'Content-Type' => 'text/plain'}, [error]]
      end

      question =
        if @question_id == 'true'
          get_first_question(@id, @identifier)
        else
          get_question_by_id(@question_id, @id, @identifier)
        end

      if question.is_a?(Hash)
        results = JSON.parse results_for_poll(survey, question['id'], forced: true)
      end

      response = { survey: survey,
                   question: question,
                   results: results}

      log "Presenting survey id #{survey[:id]} and results of question #{question['id']}" if survey && question
      log_time

      log response

      jsonp_response(@callback, JSON.dump(response))
    end

    def verify_present_poll_params
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

      # question_id missing
      if @question_id.nil?
        error = "Error: parameter 'question_id' missing"
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

    def set_present_poll_params
      @identifier     = @params['identifier']
      @callback       = @params['callback']
      @udid           = @params['udid']
      @question_id    = @params['question_id']
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
