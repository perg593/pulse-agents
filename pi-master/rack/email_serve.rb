# frozen_string_literal: true

module Rack
  module EmailServe
    include Common

    ALLOWED_SENDERS = %w(amp@gmail.dev hello@pulseinsights.com).freeze

    def email_serve_call
      set_email_serve_params
      errors = verify_params[:errors]
      return [400, {'Content-Type' => 'text/plain'}, [errors]] unless errors.empty?

      error = verify_account(@identifier, nil)
      return error if error.any?

      error_message = verify_ip_address
      return [200, {'Content-Type' => 'text/plain'}, [error_message]] if error_message

      device = get_device_by_client_key(@client_key)
      @udid ||= device[:udid] || SecureRandom.uuid
      device_id = device[:id] || get_device_id(@udid)

      CreateDeviceWorker.new.perform(@udid, @client_key) unless device_id

      # need to add any provided device_data to db, so that filter_survey will have access to it
      SetDeviceDataWorker.new.perform(@udid, @device_data.merge("identifier" => @identifier)) if @device_data

      surveys = get_surveys_for_email(@identifier, @client_key, @udid, @survey_id, @custom_data)

      if surveys.empty?
        log "No survey to serve"
        log_time
        return json_response(["{}"])
      end

      survey = surveys.sample

      submission_udid = SecureRandom.uuid
      ServeWorker.perform_async(serve_worker_params(survey[:id], submission_udid, device_id))

      response_payload = build_payload(survey, submission_udid)

      json_response([JSON.dump(response_payload)], { 'Content-Type' => 'application/json' }.merge(cors_headers))
    end

    private

    def build_payload(survey, submission_udid)
      questions_and_answers = get_questions_and_possible_answers_for_email(@identifier, survey)

      response_payload = {
        survey: {
          id: survey[:id],
          submission_udid: submission_udid,
          first_question_and_possible_answers: questions_and_answers.first,
          questions_and_possible_answers: survey[:invitation] ? questions_and_answers : questions_and_answers[1..],
          thank_you_message: survey[:thank_you_message],
          device_udid: @udid,
          personal_data_masking_enabled: survey[:personal_data_masking_enabled],
          phone_number_masked:           survey[:phone_number_masked],
          email_masked:                  survey[:email_masked]
        }
      }

      fill_in_invitation(survey, questions_and_answers.first[:question_id], response_payload) if survey[:invitation]

      response_payload
    end

    def set_email_serve_params
      # required
      @identifier = @params['identifier']
      @client_key = valid_client_key?(@params['client_key']) ? @params['client_key'] : nil

      # optional
      @survey_id = @params['survey_id']
      @udid = @params['udid'] # only required for previous_answer targeting
      @custom_data = @params['custom_data']

      if @params['device_data']
        begin
          @device_data = JSON.parse(@params['device_data'])
        rescue
          log "Failed to parse device_data #{@params['device_data']}"
        end
      end

      @sender_email = @env["HTTP_AMP_EMAIL_SENDER"]

      # obligatory...
      @url = ''
    end

    def verify_params
      status = {errors: []}

      unless @client_key
        status[:errors] << "Error: Parameter 'client_key' missing"
      end

      if @sender_email
        status[:errors] << "#{@sender_email} not found in list of approved senders" unless ALLOWED_SENDERS.include? @sender_email
      else
        status[:errors] << "Invalid CORS headers"
      end

      log status[:errors] unless status[:errors].empty?

      status
    end

    def fill_in_invitation(survey, first_question_id, response_payload)
      response_payload[:survey][:invitation] = {
        label_text: survey[:invitation],
        button_text: survey[:invitation_button],
        button_present: survey[:invitation_button_disabled] != 't',
        first_question_id: first_question_id
      }
    end

    def cors_headers
      {
        "AMP-Email-Allow-Sender" => @sender_email
      }
    end
  end
end
