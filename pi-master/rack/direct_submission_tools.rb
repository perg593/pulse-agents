# frozen_string_literal: true

module Rack
  module DirectSubmissionTools
    include Common
    def check_if_survey_exists
      if @survey.nil?
        # Probably the survey isn't live anymore
        log "Error: can't find survey"
        log_time
        [404, {'Content-Type' => 'text/plain'}, ["Error: can't find survey"]]
      else
        []
      end
    end

    def verify_text_answer_presence
      log "> Free text question"

      if @text_answer.nil? || @text_answer == ""
        log "Missing text answer"
        log_time
        [400, {'Content-Type' => 'text/plain'}, ['Missing text answer']]
      else
        []
      end
    end

    def verify_direct_submission_params
      # Verify if it's not a bot
      if @user_agent && VoightKampff::Test.new(@user_agent).bot?
        return [403, {'Content-Type' => 'text/plain'}, ['']]
      end

      error = verify_identifier
      return error unless error.empty?

      error = verify_account(@identifier, nil)
      return error if error.any?

      error = verify_redirect
      return error if error.any?

      if @question_id.zero?
        log "Invalid URL #{@request_path}"
        log_time
        return [404, {'Content-Type' => 'text/plain'}, ['question_id == 0']]
      end

      @is_free_text = question_free_text(@question_id)

      # That would mean there's no questions with that ID in the DB
      if @is_free_text.nil?
        log "Invalid question id #{@question_id} - not found in database"
        log_time
        return [404, {'Content-Type' => 'text/plain'}, ['is_free_text.nil?']]
      end

      []
    end

    def verify_answer_id
      if @answer_id.zero?
        log "Invalid URL #{@request_path}"
        log @request_path
        log_time
        return [404, {'Content-Type' => 'text/plain'}, ['answer_id == 0']]
      end

      []
    end

    def verify_redirect
      return [] if @redirect.empty?
      redirect_domain = URI.parse(@redirect).host

      allowed_domains = PG::TextDecoder::Array.new.decode(@account.first['domains_to_allow_for_redirection'])
      return [] if allowed_domains.any? { |allowed_domain| redirect_domain.match?(/.*#{allowed_domain}$/) }

      log_time
      [400, {'Content-Type' => 'text/plain'}, ['"redirect" parameter not valid']]
    end

    def set_answer_id
      @request_path =~ /^\/q\/([0-9]+)\/a\/([0-9]+)/
      @answer_id = Regexp.last_match(2).to_i
    end

    def set_direct_submission_params
      @headers = {}
      @udid = @params['udid'] || SecureRandom.uuid
      @custom_data = {}
      @user_agent = @env['HTTP_USER_AGENT']
      @identifier = @params['identifier']
      @text_answer = @params['text']
      @preview_mode = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')
      @request_path = @env['REQUEST_PATH']
      # Gather custom data from whatever GET parameters we got
      @parameters_to_exclude = %w(identifier question_id answer_id text redirect preview_mode)
      @request_path =~ /^\/q\/([0-9]+)/
      @question_id = Regexp.last_match(1).to_i
      @url = @params['url'] || @env['HTTP_REFERER'] || ''
      @redirect = @params['redirect'] || @url
      @ip_address = @env['HTTP_X_REAL_IP']
    end

    def populate_custom_data
      @params.each_key do |key|
        @custom_data.merge!(key => @params[key]) unless @parameters_to_exclude.include?(key)
      end

      begin
        @custom_data = JSON.dump(@custom_data)
      rescue StandardError => e
        log "Error: An error occured trying to generate custom data: #{e.inspect}"
      end
    end
  end
end
