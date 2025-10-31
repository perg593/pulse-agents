# frozen_string_literal: true
module Rack
  module SurveyQuestions
    include Common

    def load_survey_questions_call
      # Verify if we have an identifier
      error = verify_identifier
      return error unless error.empty?
      identifier = @params["identifier"]

      error = verify_account(identifier, @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      # Verify the id
      @env['REQUEST_PATH'] =~ /\/surveys\/([0-9]+)\/questions/
      id = Regexp.last_match(1).to_i
      if id.zero?
        log "Invalid URL #{@env['REQUEST_PATH']}"
        return [404, {'Content-Type' => 'text/plain'}, ["Not found"]]
      end

      # Fetch the survey in the database and return all questions and possible answers
      questions_and_possible_answers = load_survey_questions_and_possible_answers(identifier, id)

      log_time

      jsonp_response(@params["callback"], JSON.dump(questions_and_possible_answers))
    end
  end
end
