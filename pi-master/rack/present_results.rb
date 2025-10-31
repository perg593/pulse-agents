# frozen_string_literal: true

module Rack
  module Results
    include Common

    def present_results
      required_params = %w(identifier submission_udid)

      error = verify_required_params(required_params)
      return error if error

      error = verify_identifier
      return error unless error.empty?

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      thank_you_and_poll = get_thank_you_and_poll(@params['submission_udid'])

      unless thank_you_and_poll
        error = "Error: Parameter 'submission_udid' incorrect or no answers"
        log error
        return [400, {'Content-Type' => 'text/plain'}, [error]]
      end

      res =
        if thank_you_and_poll['poll_enabled'] == 't'
          {
            poll: get_poll(thank_you_and_poll['question_id']),
            content: thank_you_and_poll['content'],
            question_type: thank_you_and_poll['question_type'],
            answers_via_checkbox: get_answers_via_checkbox(@params['submission_udid'], thank_you_and_poll['question_id'])
          }
        else
          { thank_you: thank_you_and_poll['thank_you'] }
        end

      jsonp_response @params['callback'], JSON.dump(res)
    end
  end
end
