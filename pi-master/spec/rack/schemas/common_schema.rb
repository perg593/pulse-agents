# frozen_string_literal: true
module RackSchemas
  # Needed so we can define enums
  module CustomTypes
    include Dry.Types()
  end

  # rubocop:disable Metrics/ModuleLength
  # We have a lot of schemas to define
  module Common
    QuestionType = CustomTypes::String.enum("single_choice_question", "free_text_question", "custom_content_question", "multiple_choices_question",
                                            "slider_question")
    StringBoolean = CustomTypes::String.enum("t", "f")

    SubmissionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:udid).value(:string) # TODO: consider specifying structure
    end

    MissingParameterErrorResponse = Dry::Schema.JSON do
      Dry.Types::Array.of(:string)
    end

    PollResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:string)
      required(:content).value(:string)
      required(:count).value(:integer)
    end

    PollQuestionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:id).value(:string)
      required(:question_type).value(:string)
      required(:content).value(:string)
      required(:question_locale_group_id) { nil? | str? }
    end

    PossibleAnswerSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:content).value(:string)
      required(:id).value(:integer)
      required(:image_alt) { nil? | str? }
      required(:image_height) { nil? | str? }
      required(:image_height_mobile) { nil? | str? }
      required(:image_height_tablet) { nil? | str? }
      required(:image_position) { nil? | str? }
      required(:image_url) { nil? | str? }
      required(:image_width) { nil? | str? }
      required(:image_width_mobile) { nil? | str? }
      required(:image_width_tablet) { nil? | str? }
      required(:next_question_id) { nil? | int? }
      required(:position).value(:integer)
      required(:possible_answer_locale_group_id) { nil? | int? }
    end

    # All question responses return these keys
    BaseQuestionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      optional(:additional_content) { nil? | str? } # not present if show_additional_content == f
      optional(:additional_content_position) { nil? | int? } # not present if show_additional_content == f
      required(:after_answers_count) { nil? | int? }
      required(:after_answers_items) { nil? | type?(Dry.Types::Array.of(:string)) }
      required(:after_question_text) { nil? | str? }
      required(:answers_alignment_desktop) { nil? | int? }
      required(:answers_alignment_mobile) { nil? | int? }
      required(:answers_per_row_desktop) { nil? | int? }
      required(:answers_per_row_mobile) { nil? | int? }
      required(:button_type).value(:integer)
      required(:before_answers_count) { nil? | int? }
      required(:before_answers_items) { nil? | type?(Dry.Types::Array.of(:string)) }
      required(:before_question_text) { nil? | str? }
      required(:content).value(:string)
      required(:created_at).value(:integer)
      required(:desktop_width_type).value(:integer)
      required(:empty_error_text) { nil? | str? }
      required(:id).value(:integer)
      required(:image_type) { nil? | int? }
      required(:mobile_width_type).value(:integer)
      optional(:next_question_id) { nil? | int? }
      required(:nps).value(StringBoolean)
      required(:optional).value(StringBoolean)
      required(:position).value(:integer)
      required(:question_locale_group_id) { nil? | int? }
      required(:question_type).value(QuestionType)
      required(:single_choice_default_label) { nil? | str? }
      required(:submit_label).value(:string)
    end

    SingleChoiceQuestionSchema = Dry::Schema.JSON do
      # TODO: Enable this without copy+pasting BaseQuestionSchema
      # config.validate_keys = true

      required(:possible_answers).value(Dry.Types::Array.of(PossibleAnswerSchema))
    end

    MultipleChoiceQuestionSchema = Dry::Schema.JSON do
      # TODO: Enable this without copy+pasting BaseQuestionSchema
      # config.validate_keys = true

      required(:possible_answers).value(Dry.Types::Array.of(PossibleAnswerSchema))
      optional(:maximum_selection).value(:integer) # only appears if questions.enable_maximum_selection is true
      optional(:maximum_selections_exceeded_error_text) { nil? | str? } # only appears if questions.enable_maximum_selection is true
    end

    FreeTextQuestionSchema = Dry::Schema.JSON do
      # TODO: Enable this without copy+pasting BaseQuestionSchema
      # config.validate_keys = true

      required(:error_text) { nil? | str? }
      required(:height) { nil? | int? }
      required(:hint_text) { nil? | str? }
      required(:max_length) { nil? | int? }
    end

    CustomContentQuestionSchema = Dry::Schema.JSON do
      # TODO: Enable this without copy+pasting BaseQuestionSchema
      # config.validate_keys = true

      required(:autoredirect_delay) { nil? | int? }
      required(:autoredirect_enabled) { nil? | type?(StringBoolean) }
      required(:autoredirect_url) { nil? | str? }
      required(:autoclose_delay) { nil? | int? }
      required(:autoclose_enabled) { nil? | type?(StringBoolean) }
      required(:background_color) { nil? | str? }
      required(:fullscreen).value(StringBoolean)
      required(:opacity) { nil? | int? }
      required(:show_after_aao).value(:bool)
    end

    SliderQuestionSchema = Dry::Schema.JSON do
      # TODO: Enable this without copy+pasting BaseQuestionSchema
      # config.validate_keys = true

      required(:slider_start_position) { nil? | str? }
      required(:slider_submit_button_enabled).value(StringBoolean)
      required(:possible_answers).value(Dry.Types::Array.of(PossibleAnswerSchema))
    end

    # single_page (StringBoolean instead of boolean)
    # ignore_frequency_cap (StringBoolean instead of boolean)
    # custom_content_link_click_enabled absence
    # render_after_x_seconds absence
    # render_after_x_seconds_enabled absence
    # >:|
    # TODO: Bring this into harmony with the other survey schema
    DirectSurveySchema = Dry::Schema.JSON do
      # 0=>, 1=> type keys are not supported :(
      # config.validate_keys = true

      required(:all_at_once_empty_error_enabled).value(StringBoolean)
      required(:all_at_once_error_text).value(:string)
      required(:all_at_once_submit_label).value(:string)
      required(:answer_text_color) { nil? | str? }
      optional(:background).value(:string)
      required(:background_color) { nil? | str? }
      required(:bottom_position) { nil? | str? }
      required(:custom_css) { nil? | str? } # deprecated
      required(:custom_data_snippet) { nil? | str? }
      required(:display_all_questions).value(StringBoolean)
      required(:email_masked).value(:bool)
      required(:fullscreen_margin) { nil? | int? }
      required(:id).value(:integer)
      required(:ignore_frequency_cap).value(StringBoolean)
      required(:invitation).value(:string)
      required(:invitation_button) { nil? | str? }
      required(:invitation_button_disabled).value(StringBoolean)
      required(:inline_target_position) { nil? | str? }
      required(:inline_target_selector) { nil? | str? }
      required(:left_position) { nil? | str? }
      required(:logo) { nil? | str? } # deprecated
      required(:name).value(:string)
      required(:mobile_inline_target_selector) { nil? | str? }
      required(:onanswer_callback_code).maybe(:string)
      required(:onclick_callback_code) { nil? | str? }
      required(:onclose_callback_code) { nil? | str? }
      required(:oncomplete_callback_code) { nil? | str? }
      required(:onview_callback_code) { nil? | str? }
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:pulse_insights_branding).value(:bool)
      required(:pusher_enabled).value(StringBoolean) # deprecated
      required(:randomize_question_order).value(StringBoolean)
      required(:right_position).value(:string)
      required(:sdk_inline_target_selector) { nil? | str? }
      required(:single_page).value(StringBoolean)
      required(:survey_locale_group_id) { nil? | int? }
      required(:survey_type).value(:integer)
      required(:text_color) { nil? | str? }
      required(:thank_you).value(:string)
      required(:theme_css) { nil? | str? }
      required(:top_position) { nil? | str? }
      required(:width).value(:integer)
    end

    # single_page (StringBoolean instead of boolean)
    # onview_callback_code absence
    # theme_css absence
    # theme_native presence
    # sdk_widget_height presence
    # render_after_x_seconds integer
    # T_T
    # TODO: Bring this into harmony with the other survey schema
    NativeSurveySchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:all_at_once_empty_error_enabled).value(StringBoolean)
      required(:all_at_once_error_text).value(:string)
      required(:all_at_once_submit_label).value(:string)
      required(:answer_text_color) { nil? | str? }
      optional(:background).value(:string)
      required(:background_color) { nil? | str? }
      required(:bottom_position) { nil? | str? }
      required(:custom_content_link_click_enabled).maybe(:string)
      required(:custom_css) { nil? | str? } # deprecated
      required(:custom_data_snippet) { nil? | str? }
      required(:display_all_questions).value(StringBoolean)
      required(:email_masked).value(:bool)
      required(:fullscreen_margin) { nil? | int? }
      required(:id).value(:integer)
      required(:ignore_frequency_cap).value(:bool)
      required(:invitation).value(:string)
      required(:invitation_button) { nil? | str? }
      required(:invitation_button_disabled).value(StringBoolean)
      required(:inline_target_position) { nil? | str? }
      required(:inline_target_selector) { nil? | str? }
      required(:left_position) { nil? | str? }
      required(:logo) { nil? | str? } # deprecated
      required(:name).value(:string)
      required(:mobile_inline_target_selector) { nil? | str? }
      required(:onanswer_callback_code).maybe(:string)
      required(:onclose_callback_code) { nil? | str? }
      required(:oncomplete_callback_code) { nil? | str? }
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:pulse_insights_branding).value(:bool)
      required(:pusher_enabled).value(StringBoolean) # deprecated
      required(:randomize_question_order).value(StringBoolean)
      required(:render_after_x_seconds).maybe(:integer)
      required(:render_after_x_seconds_enabled).maybe(:string)
      required(:right_position).value(:string)
      required(:sdk_inline_target_selector) { nil? | str? }
      required(:sdk_widget_height).value(:integer)
      required(:single_page).value(StringBoolean)
      required(:survey_locale_group_id) { nil? | int? }
      required(:survey_type).value(:integer)
      required(:theme_native).maybe do
        schema do
          optional(:theme).value(:string)
        end
      end
      required(:text_color) { nil? | str? }
      required(:thank_you).value(:string)
      required(:top_position) { nil? | str? }
      required(:width).value(:integer)
    end

    # ignore_frequency_cap (StringBoolean instead of boolean)
    # single_page (StringBoolean instead of boolean)
    # D:
    # TODO: Bring this into harmony with the other survey schema
    PresentEventSurveySchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:all_at_once_empty_error_enabled).value(StringBoolean)
      required(:all_at_once_error_text).value(:string)
      required(:all_at_once_submit_label).value(:string)
      required(:answer_text_color) { nil? | str? }
      optional(:background).value(:string)
      required(:background_color) { nil? | str? }
      required(:bottom_position) { nil? | str? }
      required(:custom_content_link_click_enabled).value(:string)
      required(:custom_css) { nil? | str? } # deprecated
      required(:custom_data_snippet) { nil? | str? }
      required(:display_all_questions).value(StringBoolean)
      required(:email_masked).value(:bool)
      required(:fullscreen_margin) { nil? | int? }
      required(:id).value(:integer)
      required(:ignore_frequency_cap).value(StringBoolean)
      required(:invitation).value(:string)
      required(:invitation_button) { nil? | str? }
      required(:invitation_button_disabled).value(StringBoolean)
      required(:inline_target_position) { nil? | str? }
      required(:inline_target_selector) { nil? | str? }
      required(:left_position) { nil? | str? }
      required(:logo) { nil? | str? } # deprecated
      required(:name).value(:string)
      required(:mobile_inline_target_selector) { nil? | str? }
      required(:onanswer_callback_code) { nil? | str? }
      required(:onclick_callback_code) { nil? | str? }
      required(:onclose_callback_code) { nil? | str? }
      required(:oncomplete_callback_code) { nil? | str? }
      required(:onview_callback_code) { nil? | str? }
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:pulse_insights_branding).value(:bool)
      required(:pusher_enabled).value(StringBoolean) # deprecated
      required(:randomize_question_order).value(StringBoolean)
      required(:right_position).value(:string)
      required(:sdk_inline_target_selector) { nil? | str? }
      required(:single_page).value(StringBoolean)
      required(:survey_locale_group_id) { nil? | int? }
      required(:survey_type).value(:integer)
      required(:text_color) { nil? | str? }
      required(:thank_you).value(:string)
      required(:theme_css) { nil? | str? }
      required(:top_position) { nil? | str? }
      required(:width).value(:integer)
    end

    # *_*
    # ignore_frequency_cap (StringBoolean instead of boolean)
    # single_page (StringBoolean instead of boolean)
    # TODO: Bring this into harmony with the other survey schema
    PresentSurveySchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:all_at_once_empty_error_enabled).value(StringBoolean)
      required(:all_at_once_error_text).value(:string)
      required(:all_at_once_submit_label).value(:string)
      required(:answer_text_color) { nil? | str? }
      optional(:background).value(:string)
      required(:background_color) { nil? | str? }
      required(:bottom_position) { nil? | str? }
      required(:custom_content_link_click_enabled).value(:string)
      required(:custom_css) { nil? | str? } # deprecated
      required(:custom_data_snippet) { nil? | str? }
      required(:display_all_questions).value(StringBoolean)
      required(:email_masked).value(:bool)
      required(:fullscreen_margin) { nil? | int? }
      required(:id).value(:integer)
      required(:ignore_frequency_cap).value(StringBoolean)
      required(:invitation).value(:string)
      required(:invitation_button) { nil? | str? }
      required(:invitation_button_disabled).value(StringBoolean)
      required(:inline_target_position) { nil? | str? }
      required(:inline_target_selector) { nil? | str? }
      required(:left_position) { nil? | str? }
      required(:logo) { nil? | str? } # deprecated
      required(:name).value(:string)
      required(:mobile_inline_target_selector) { nil? | str? }
      required(:onanswer_callback_code) { nil? | str? }
      required(:onclick_callback_code) { nil? | str? }
      required(:onclose_callback_code) { nil? | str? }
      required(:oncomplete_callback_code) { nil? | str? }
      required(:onview_callback_code) { nil? | str? }
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:pulse_insights_branding).value(:bool)
      required(:pusher_enabled).value(StringBoolean) # deprecated
      required(:randomize_question_order).value(StringBoolean)
      required(:right_position).value(:string)
      required(:sdk_inline_target_selector) { nil? | str? }
      required(:single_page).value(StringBoolean)
      required(:survey_locale_group_id) { nil? | int? }
      required(:survey_type).value(:integer)
      required(:text_color) { nil? | str? }
      required(:thank_you).value(:string)
      required(:theme_css) { nil? | str? }
      required(:top_position) { nil? | str? }
      required(:width).value(:integer)
    end

    # These are in SurveySchema and no other survey related schemas
    #
    # render_after_x_percent_scroll
    # render_after_x_percent_scroll_enabled
    # render_after_intent_exit_enabled
    # render_after_element_clicked
    # render_after_element_clicked_enabled
    # render_after_element_visible
    # render_after_element_visible_enabled
    # text_on_page_enabled
    # text_on_page_presence
    # text_on_page_selector
    # text_on_page_value
    SurveySchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:all_at_once_empty_error_enabled).value(StringBoolean)
      required(:all_at_once_error_text).value(:string)
      required(:all_at_once_submit_label).value(:string)
      required(:answer_text_color) { nil? | str? }
      optional(:background).value(:string)
      required(:background_color) { nil? | str? }
      required(:bottom_position) { nil? | str? }
      required(:custom_content_link_click_enabled).value(:string)
      required(:custom_css) { nil? | str? } # deprecated
      required(:custom_data_snippet) { nil? | str? }
      required(:display_all_questions).value(StringBoolean)
      required(:email_masked).value(:bool)
      required(:fullscreen_margin) { nil? | int? }
      required(:id).value(:integer)
      required(:ignore_frequency_cap).value(:bool)
      required(:invitation).value(:string)
      required(:invitation_button) { nil? | str? }
      required(:invitation_button_disabled).value(StringBoolean)
      required(:inline_target_position) { nil? | str? }
      required(:inline_target_selector) { nil? | str? }
      required(:left_position) { nil? | str? }
      required(:logo) { nil? | str? } # deprecated
      required(:name).value(:string)
      required(:mobile_inline_target_selector) { nil? | str? }
      required(:onanswer_callback_code).maybe(:string)
      required(:onclick_callback_code) { nil? | str? }
      required(:onclose_callback_code) { nil? | str? }
      required(:oncomplete_callback_code) { nil? | str? }
      required(:onview_callback_code) { nil? | str? }
      required(:personal_data_masking_enabled).value(:bool)
      required(:phone_number_masked).value(:bool)
      required(:pulse_insights_branding).value(:bool)
      required(:pusher_enabled).value(StringBoolean) # deprecated
      required(:render_after_element_clicked).maybe(:string)
      required(:render_after_element_clicked_enabled).maybe(:string)
      required(:render_after_element_visible).maybe(:string)
      required(:render_after_element_visible_enabled).maybe(:string)
      required(:render_after_intent_exit_enabled).maybe(:string)
      required(:render_after_x_percent_scroll).maybe(:integer)
      required(:render_after_x_percent_scroll_enabled).maybe(:string)
      required(:render_after_x_seconds).maybe(:string)
      required(:render_after_x_seconds_enabled).maybe(:string)
      required(:randomize_question_order).value(StringBoolean)
      required(:right_position).value(:string)
      required(:sdk_inline_target_selector) { nil? | str? }
      required(:single_page).value(:bool)
      required(:survey_locale_group_id) { nil? | int? }
      required(:survey_type).value(:integer)
      required(:text_color) { nil? | str? }
      required(:text_on_page_enabled).maybe(:string)
      required(:text_on_page_presence).maybe(:string)
      required(:text_on_page_selector).maybe(:string)
      required(:text_on_page_value).maybe(:string)
      required(:thank_you).value(:string)
      required(:theme_css) { nil? | str? }
      required(:top_position) { nil? | str? }
      required(:width).value(:integer)
    end

    NoSurveyFoundResponseSchema = Dry::Schema.JSON do
      config.validate_keys = true

      Dry::Schema::EMPTY_HASH
    end
  end
end
