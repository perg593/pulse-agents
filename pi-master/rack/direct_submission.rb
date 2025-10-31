# frozen_string_literal: true

require File.join(File.dirname(__FILE__), 'common')
require File.join(File.dirname(__FILE__), '../app/workers/direct_submission_worker')
require 'voight_kampff'

module Rack
  module PresentSurvey
    include Common
    include DirectSubmissionTools

    # Direct submission call (aka. bring your own UI)
    def direct_submission_call
      set_direct_submission_params

      error = verify_direct_submission_input
      return error if error&.any?

      error = verify_redirect
      return error if error.any?

      log "Question id: #{@question_id}"

      if @is_free_text
        error = verify_text_answer_presence
        return error if error.any?
      else
        set_answer_id
        error = verify_answer_id
        return error if error.any?
        @text_answer = nil
        log "> Single choice question"
        log "Answer id: #{@answer_id}"
      end

      populate_custom_data

      @survey = get_survey_with_question(@question_id)
      error = check_if_survey_exists
      return error if error.any?

      @survey_with_rules = get_survey_with_question_and_rules(@question_id, @preview_mode)

      return redirect_to_poll_or_thank_you if @params['poll_or_ty']

      if @survey_with_rules
        DirectSubmissionWorker.perform_async(@identifier, @udid, @survey[:id], @url, @ip_address, @user_agent, @custom_data, @question_id, @answer_id,
                                             @text_answer)
      end

      redirect_or_thank_you
    end

    private

    def redirect_to_poll_or_thank_you
      submission_udid = SecureRandom.uuid
      if @survey_with_rules
        DirectSubmissionWorker.new.perform(@identifier, @udid, @survey[:id], @url, @ip_address, @user_agent, @custom_data, @question_id, @answer_id,
                                           @text_answer, submission_udid)
      end

      scheme = %w(production staging develop).include?(@environment) ? 'https' : 'http'
      url = "#{scheme}://#{survey_host}/results?submission_udid=#{submission_udid}&identifier=#{@identifier}"
      log "Redirecting to #{url}"
      @headers['Location'] = url
      [302, @headers, ['']]
    end

    def redirect_or_thank_you
      if !@redirect.nil? && (@redirect != '')
        log "Redirecting to #{@redirect.inspect}"
        @headers['Location'] = @redirect
        log_time
        [302, @headers, ['']]
      else
        log 'Returning text/plain thank you message'
        @headers['Content-Type'] = 'text/plain'
        log_time
        [200, @headers, ["Thank you!"]]
      end
    end

    def verify_direct_submission_input
      required_params = %w(identifier)

      error = verify_required_params(required_params)
      return error if error

      error = verify_direct_submission_params
      return error if error.any?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message
    end
  end
end
