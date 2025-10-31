# frozen_string_literal: true
# rubocop:disable Metrics/ModuleLength
require File.join(File.dirname(__FILE__), '../app/workers/update_close_by_user_worker')
require File.join(File.dirname(__FILE__), '../app/workers/update_submission_viewed_at_worker')
require File.join(File.dirname(__FILE__), '../app/workers/submissions_answer_worker')
require File.join(File.dirname(__FILE__), '../app/workers/submissions_all_answers_worker')

require File.join(File.dirname(__FILE__), 'pdf_response')

module Rack
  module Submissions
    def submissions_close_call
      # Verify the id
      error = submissions_verify_id
      return error unless error.empty?

      @env['REQUEST_PATH'] =~ /\/submissions\/([-a-zA-Z0-9]+)\/close/
      submission_udid = Regexp.last_match(1)
      log submission_udid
      UpdateCloseByUserWorker.perform_async(submission_udid)

      log_time
      jsonp_response(@params["callback"], "{}")
    end

    def submissions_viewed_at_call
      required_params = %w(viewed_at)

      error = verify_required_params(required_params)
      return error if error

      error = submissions_verify_id
      return error unless error.empty?

      error = submissions_verify_viewed_at(@params['viewed_at'])
      return error unless error.empty?

      @env['REQUEST_PATH'] =~ /\/submissions\/([-a-zA-Z0-9]+)\/viewed_at/
      submission_udid = Regexp.last_match(1)
      UpdateSubmissionViewedAtWorker.perform_async(submission_udid, @params['viewed_at'])

      log_time
      jsonp_response(@params["callback"], "{}")
    end

    def submissions_all_answers_call
      required_params = %w(identifier answers)

      error = verify_required_params(required_params)
      return error if error

      # Verify if we have an identifier
      error = verify_identifier
      return error unless error.empty?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      # Verify the submission id
      error = submissions_verify_id
      return error unless error.empty?

      # Check if there is any error in params (answers)
      error = submissions_verify_answers(@params['answers'])

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      # Return 400 if any error
      if error.any?
        log error
        return error
      end

      @env['REQUEST_PATH'] =~ /\/submissions\/([-a-zA-Z0-9]+)\/all_answers/
      submission_udid = Regexp.last_match(1)

      answers = JSON.parse(@params['answers'])

      unless @params['preview_mode'] == 'true'
        SubmissionsAllAnswersWorker.perform_async(@params['identifier'], submission_udid, answers, @params['custom_data'], @params['client_key'])
      end

      if @params['pdf_results'] == 'true'
        PDFResponse.new(@pg_connection, answers).generate
      else
        jsonp_response(@params['callback'], '{}')
      end
    end

    def email_submissions_answer_call
      answer_id = @params.detect { |key, _val| key =~ /question_\d*_possible_answer_id/ }&.last

      UpdateSubmissionViewedAtWorker.perform_async(@params['submission_udid'], Time.current.to_s) unless @params['preview_mode'] == 'true'

      submissions_answer_call(@params["submission_udid"], answer_id)
    end

    def submissions_answer_call(submission_udid = nil, answer_id = nil)
      @params["answer_id"] ||= answer_id

      required_params = %w(identifier question_id)

      error = verify_required_params(required_params)
      return error if error

      # Verify if we have an identifier
      error = verify_identifier
      return error unless error.empty?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      # Verify the id
      error = submissions_verify_id
      return error unless error.empty?

      if submission_udid.nil?
        @env['REQUEST_PATH'] =~ /\/submissions\/([-a-zA-Z0-9]+)\/answer/
        submission_udid = Regexp.last_match(1)
      end

      # Check if there is any error in params
      error = submissions_answer_call_error

      # Return 400 if any error
      if error.any?
        log error
        return error
      end

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      # Verify if we have to return results for poll
      survey = get_survey(@params['question_id']).first
      results = results_for_poll(survey, @params['question_id'])

      unless @params['preview_mode'] == 'true'
        SubmissionsAnswerWorker.perform_async(@params['identifier'], submission_udid, @params['question_id'], @params['answer_id'],
                                              @params['text_answer'], @params['custom_data'], @params['check_boxes'], @params['client_key'])
      end

      jsonp_response(@params['callback'], results)
    end

    def submissions_answer_call_error
      # Verify the answer id or the text_answer presence
      error = submissions_verify_answer(@params['answer_id'], @params['text_answer'], @params['next_question_id'], @params['check_boxes'])

      # Verify the question id presence
      error = submissions_verify_question(@params['question_id']) if error.empty?

      error
    end

    def submissions_verify_id
      @env['REQUEST_PATH'] =~ /\/submissions\/([-a-zA-Z0-9]+)\//
      submission_udid = Regexp.last_match(1)

      # the condition is loose so a survey demo on the edit page works https://gitlab.ekohe.com/ekohe/pi/-/issues/1636
      if (submission_udid.is_a?(Integer) && submission_udid.zero?) || (submission_udid.is_a?(String) && submission_udid == 'undefined')
        log "Invalid URL #{@env['REQUEST_PATH']}"
        [404, {'Content-Type' => 'text/plain'}, ['Not found']]
      else
        []
      end
    end

    def submissions_verify_answer(answer_id, text_answer, next_question_id, check_boxes)
      if answer_id.to_i.zero? && text_answer.nil? && next_question_id.nil? && check_boxes.nil?
        [400, {'Content-Type' => 'text/plain'}, ["One of 'answer_id' or 'text_answer' parameter is missing or invalid"]]
      else
        []
      end
    end

    def submissions_verify_question(question_id)
      if question_id.to_i.zero?
        [400, {'Content-Type' => 'text/plain'}, ["Parameter 'question_id' missing or invalid"]]
      else
        []
      end
    end

    def submissions_verify_answers(answers)
      begin
        JSON.parse(answers)
      rescue
        return [400, {'Content-Type' => 'text/plain'}, ["Error: Parameter 'answers' incorrect"]]
      end

      []
    end

    def submissions_verify_viewed_at(viewed_at)
      Time.parse(viewed_at)
      []
    rescue
      [400, {'Content-Type' => 'text/plain'}, ["Parameter 'viewed_at' invalid"]]
    end

    def results_for_poll(survey, question_id, forced: false)
      if (survey['questions_size'] == '1' && survey['poll_enabled'] == 't') || forced
        JSON.dump(get_poll(question_id))
      else
        '{}'
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
