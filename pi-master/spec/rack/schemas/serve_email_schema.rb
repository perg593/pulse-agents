# frozen_string_literal: true
require File.join(File.dirname(__FILE__), './common_schema')

module RackSchemas
  module ServeEmail
    InvitationSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:label_text).value(:string)
      required(:button_text) { nil? | str? }
      required(:button_present).value(:bool)
      required(:first_question_id).value(:string)
    end

    PossibleAnswerSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:possible_answer_id).value(:integer)
      required(:content).value(:string)
      required(:next_question_id).value(:integer)
      optional(:image_url).value(:string)

      optional(:is_free_text_question).value(:bool)
      optional(:question_button_label).value(:string)
      optional(:max_length).value(:integer)
      optional(:hint_text).value(:string)
      optional(:error_text).value(:string)

      optional(:single_choice_default_label).value(:string)
    end

    QuestionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:question_id).value(:integer)
      required(:content).value(:string)
      required(:possible_answers).value(:hash)
      required(:possible_answers).value(Dry.Types::Array.of(PossibleAnswerSchema))
    end

    EmailSurveySchema = Dry::Schema.JSON do
      required(:id).value(:string)
      required(:submission_udid).value(:string)
      required(:first_question_and_possible_answers).value(:hash)
      required(:questions_and_possible_answers).value(Dry.Types::Array.of(:hash))
      required(:thank_you_message).value(:string)
      required(:device_udid).value(:string)
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:email_masked).value(:bool)
      optional(:invitation).value(InvitationSchema)
    end

    SuccessfulResponseSchema = Dry::Schema.JSON do
      required(:survey).value(EmailSurveySchema)
    end

    ErrorResponseSchema = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end
  end
end
