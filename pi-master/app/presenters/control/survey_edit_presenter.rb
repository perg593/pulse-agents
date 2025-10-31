# frozen_string_literal: true

module Control
  class SurveyEditPresenter
    include Admin::CustomAuditsHelper
    include Control::SurveysHelper
    include Control::DeviceDataTriggerHelper
    include Rails.application.routes.url_helpers

    attr_accessor :open_tab_name

    QUESTION_TYPE_LABELS = {
      single_choice_question: "SINGLE CHOICE",
      free_text_question: "FREE TEXT CAPTURE",
      custom_content_question: "CUSTOM CONTENT",
      multiple_choices_question: "MULTIPLE CHOICE",
      slider_question: "SLIDER"
    }.freeze

    def initialize(survey, current_user, open_tab_name)
      @survey = survey
      @current_user = current_user
      @open_tab_name = open_tab_name
    end

    def editor_props
      {
        surveyId: @survey.id,
        surveyData: survey_data,
        questionData: question_data,
        surveyPreviewData: @survey.attributes_for_javascript,
        livePreviewUrl: @current_user.live_preview_url,
        surveyTags: survey_tags,
        surveyGeneralOptions: survey_general_options,
        surveyFormattingOptions: survey_formatting_options,
        surveyTargetingOptions: survey_targeting_options,
        surveyListData: survey_list_sidebar_data,
        openTabName: open_tab_name,
        htmlAttributeMap: SurveyEditPresenter.html_attribute_map,
        disableStructuralChanges: @survey.localized?,
        readOnly: @current_user.reporting?,
        isAdmin: @current_user.admin?
      }
    end

    def question_data
      unless @question_data
        @question_data = []

        @survey.questions.each_with_index do |question, question_index|
          @question_data << per_question_data(question, question_index)
        end
      end

      @question_data
    end

    def survey_list_sidebar_data
      surveys_visited = []
      survey_locale_group_data = @current_user.account.survey_locale_groups.map do |survey_locale_group|
        survey_data = survey_locale_group.surveys.order(:name).map do |survey|
          surveys_visited << survey
          survey_list_survey_data(survey)
        end

        {
          type: "surveyLocaleGroup",
          name: survey_locale_group.name,
          surveys: survey_data,
          id: survey_locale_group.id,
          searchableContent: [survey_locale_group.name, survey_locale_group.id]
        }
      end

      survey_data = (@current_user.account.surveys - surveys_visited).map do |survey|
        survey_list_survey_data(survey)
      end

      (survey_locale_group_data + survey_data).sort_by { |item| item[:name] }
    end

    def survey_tags
      unless @survey_tags
        @survey_tags = @survey.account.survey_tags.map do |survey_tag|
          {
            value: { surveyTagId: survey_tag.id, appliedSurveyTagId: AppliedSurveyTag.find_by(survey_id: @survey.id, survey_tag_id: survey_tag.id)&.id },
            label: survey_tag.name
          }
        end

        @survey_tags.sort! { |a, b| a[:label] <=> b[:label] }
      end

      @survey_tags
    end

    # TODO: Address complexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def audit_log
      return [] if @current_user.reporting?

      unless @audit_log
        audits = []
        audits << @survey.audits
        audits << @survey.associated_audits.where(auditable_type: "AppliedSurveyTag")
        audits << @survey.questions.map(&:audits)
        audits << @survey.possible_answers.map(&:audits)
        audits = audits.flatten.compact.sort_by(&:created_at).reverse

        @audit_log = audits.map do |audit|
          action_description = case audit.action
          when "create"
            "Created new #{audit.auditable_type} with values:"
          when "destroy"
            "Destroyed #{audit.auditable_type}(#{audit.auditable_id})"
          when "update"
            "Updated #{audit.auditable_type}(#{audit.auditable_id}) with values:"
          end

          # Sometimes an Update has no changes
          # TODO: Make sure all Update audits have non-empty audited_changes
          values = compile_audit_changes(audit)
          next if audit.action == "update" && values.nil?

          {
            createdAt: audit.created_at,
            username: print_username(audit),
            actionDescription: action_description,
            values: values
          }
        end.compact
      end

      @audit_log.first(10)
    end

    # rubocop:disable Metrics/MethodLength
    # TODO: Simplify
    def survey_formatting_options
      # Theme for when there are no themes defined
      # Theme for when no theme is selected
      available_css_themes = themes_for_survey(:css).map do |theme_name, theme_id|
        {
          id: theme_id,
          label: theme_name
        }
      end

      available_sdk_themes = themes_for_survey(:sdk).map do |theme_name, theme_id|
        {
          id: theme_id,
          label: theme_name
        }
      end

      {
        displayAllQuestions: @survey.display_all_questions,
        allAtOnceEmptyErrorEnabled: @survey.all_at_once_empty_error_enabled,
        allAtOnceSubmitLabel: @survey.all_at_once_submit_label,
        allAtOnceErrorText: @survey.all_at_once_error_text,
        randomizeQuestionOrder: @survey.randomize_question_order,
        surveyType: @survey.survey_type,
        fullscreenMargin: @survey.fullscreen_margin,
        sdkWidgetHeight: @survey.sdk_widget_height,
        pusherEnabled: @survey.pusher_enabled,
        inlineTargetSelector: @survey.inline_target_selector,
        mobileInlineTargetSelector: @survey.mobile_inline_target_selector,
        sdkInlineTargetSelector: @survey.sdk_inline_target_selector,
        themeId: @survey.theme_id,
        sdkThemeId: @survey.sdk_theme_id,
        availableCssThemes: available_css_themes,
        availableSdkThemes: available_sdk_themes,
        customCss: @survey.custom_css,
        positionType: @survey.position_type,
        positionContent: @survey.position_content,
        inlineTargetPosition: @survey.inline_target_position
      }
    end

    def survey_general_options
      last_survey_overview_document = @survey.survey_overview_documents.last

      {
        auditLog: audit_log,
        surveyBriefEnabled: @survey.account.survey_brief_agent_enabled,
        surveyBriefJob: {
          brief: @survey.last_survey_brief_job&.brief,
          surveyId: @survey.id,
          id: @survey.last_survey_brief_job&.id,
          status: @survey.last_survey_brief_job&.status
        },
        surveyOverviewDocument: {
          isGenerating: false,
          error: last_survey_overview_document&.failure_reason,
          id: last_survey_overview_document&.id,
          status: last_survey_overview_document&.status,
          googlePresentationUrl: last_survey_overview_document&.google_presentation_url,
          failure_reason: last_survey_overview_document&.failure_reason,
          configuration: {
            target_url: last_survey_overview_document&.client_site_configuration&.dig('target_url') || '',
            cookie_selectors: last_survey_overview_document&.client_site_configuration&.dig('cookie_selectors') || [''],
            viewport_config: last_survey_overview_document&.client_site_configuration&.dig('viewport_config') || {},
            authentication_config: last_survey_overview_document&.client_site_configuration&.dig('authentication_config') || {}
          }
        }
      }
    end

    # rubocop:disable Metrics/AbcSize
    # TODO: Review complexity
    # rubocop:disable Metrics/PerceivedComplexity
    def survey_targeting_options
      triggers = @survey.triggers.map do |trigger|
        {
          id: trigger.id,
          typeCd: trigger.type_cd,
          triggerContent: trigger.trigger_content
        }
      end

      suppressers = @survey.suppressers.map do |suppresser|
        {
          id: suppresser.id,
          typeCd: suppresser.type_cd,
          triggerContent: suppresser.trigger_content
        }
      end

      trigger_options = Trigger::TYPES.map do |key, value|
        {
          label: key,
          value: value
        }
      end

      fields_to_select = "surveys.id, surveys.name, possible_answers.id possible_answer_id, possible_answers.content possible_answer_content"
      survey_options = @survey.account.surveys.select(fields_to_select).
                       where.not(id: @survey.id).joins(questions: :possible_answers).
                       where(questions: { position: 0, question_type: :single_choice_question }).
                       order(:name).group_by(&:id).map do |survey_id, surveys|
        possible_answer_options = surveys.map do |survey|
          {
            label: survey.possible_answer_content,
            value: survey.possible_answer_id
          }
        end

        {
          label: surveys.first.name,
          value: survey_id,
          possibleAnswerOptions: possible_answer_options
        }
      end

      answer_trigger_options = {
        surveyOptions: survey_options
      }

      answer_trigger = @survey.answer_triggers.first

      geoip_triggers = @survey.geoip_triggers.map do |trigger|
        {
          id: trigger.id,
          geoCountry: trigger.geo_country,
          geoStateOrDma: trigger.geo_state_or_dma
        }
      end

      geoip_trigger_options = {
        countries: GeoTrigger.geoip_countries.sort.map { |country| {label: country, value: country } },
        states: GeoTrigger.geoip_states.sort.map { |state| {label: state, value: state } },
        dmas: GeoTrigger.dma.sort.map { |dma| {label: dma.first, value: dma.last} }
      }

      device_triggers = @survey.device_triggers.map do |trigger|
        {
          id: trigger.id,
          deviceDataKey: trigger.device_data_key,
          deviceDataMatcher: trigger.device_data_matcher,
          deviceDataValue: trigger.device_data_value,
          deviceDataMandatory: trigger.device_data_mandatory
        }
      end

      device_trigger_matcher_options = device_data_matcher_options.map do |label, value|
        { label: label, value: value }
      end

      pageview_trigger = {
        id: @survey.pageview_trigger&.id,
        pageviewsCount: @survey.pageview_trigger&.pageviews_count
      }

      visit_trigger = {
        id: @survey.visit_trigger&.id,
        visitorType: @survey.visit_trigger&.visitor_type,
        visitsCount: @survey.visit_trigger&.visits_count
      }

      visit_trigger_options = {
        visitorTypeOptions: VisitTrigger.visitor_types.keys.map { |k| {label: k.titleize, value: k } }
      }

      mobile_install_trigger = {
        id: @survey.mobile_install_trigger&.id,
        mobileDaysInstalled: @survey.mobile_install_trigger&.mobile_days_installed
      }

      mobile_launch_trigger = {
        id: @survey.mobile_launch_trigger&.id,
        mobileLaunchTimes: @survey.mobile_launch_trigger&.mobile_launch_times
      }

      {
        sampleRate: @survey.sample_rate,
        desktopEnabled: @survey.desktop_enabled,
        tabletEnabled: @survey.tablet_enabled,
        mobileEnabled: @survey.mobile_enabled,
        iosEnabled: @survey.ios_enabled,
        androidEnabled: @survey.android_enabled,
        emailEnabled: @survey.email_enabled,
        triggers: triggers,
        triggerOptions: trigger_options,
        suppressers: suppressers,
        startsAt: @survey.starts_at,
        endsAt: @survey.ends_at,

        answerTriggerOptions: answer_trigger_options,

        answerTrigger: {
          id: answer_trigger&.id,
          previousAnsweredSurveyId: answer_trigger&.previous_answered_survey_id,
          previousPossibleAnswerId: answer_trigger&.previous_possible_answer_id
        },

        pageAfterSecondsTrigger: {
          id: @survey.page_after_seconds_trigger&.id,
          renderAfterXSeconds: @survey.page_after_seconds_trigger&.render_after_x_seconds,
          renderAfterXSecondsEnabled: @survey.page_after_seconds_trigger&.render_after_x_seconds_enabled
        },

        pageScrollTrigger: {
          id: @survey.page_scroll_trigger&.id,
          renderAfterXPercentScroll: @survey.page_scroll_trigger&.render_after_x_percent_scroll,
          renderAfterXPercentScrollEnabled: @survey.page_scroll_trigger&.render_after_x_percent_scroll_enabled
        },

        pageIntentExitTrigger: {
          id: @survey.page_intent_exit_trigger&.id,
          renderAfterIntentExitEnabled: @survey.page_intent_exit_trigger&.render_after_intent_exit_enabled
        },

        pageElementClickedTrigger: {
          id: @survey.page_element_clicked_trigger&.id,
          renderAfterElementClickedEnabled: @survey.page_element_clicked_trigger&.render_after_element_clicked_enabled,
          renderAfterElementClicked: @survey.page_element_clicked_trigger&.render_after_element_clicked
        },

        pageElementVisibleTrigger: {
          id: @survey.page_element_visible_trigger&.id,
          renderAfterElementVisibleEnabled: @survey.page_element_visible_trigger&.render_after_element_visible_enabled,
          renderAfterElementVisible: @survey.page_element_visible_trigger&.render_after_element_visible
        },

        textOnPageTrigger: {
          id: @survey.text_on_page_trigger&.id,
          textOnPageEnabled: @survey.text_on_page_trigger&.text_on_page_enabled || false,
          textOnPageSelector: @survey.text_on_page_trigger&.text_on_page_selector,
          textOnPagePresence: @survey.text_on_page_trigger ? @survey.text_on_page_trigger.text_on_page_presence : true,
          textOnPageValue: @survey.text_on_page_trigger&.text_on_page_value
        },

        stopShowingWithoutAnswer: @survey.stop_showing_without_answer,
        ignoreFrequencyCap: @survey.ignore_frequency_cap,
        refireEnabled: @survey.refire_enabled,
        refireTime: @survey.refire_time,
        refireTimePeriod: @survey.refire_time_period,

        refireTimePeriodOptions: Survey::REFIRE_TIME_PERIOD_OPTIONS.map { |option| {label: option, value: option} },

        goal: @survey.goal,
        geoipTriggers: geoip_triggers,
        geoipTriggerOptions: geoip_trigger_options,

        clientKeyTrigger: {
          id: @survey.client_key_trigger&.id,
          clientKeyPresence: @survey.client_key_trigger&.client_key_presence
        },

        deviceTriggers: device_triggers,
        deviceTriggerMatcherOptions: device_trigger_matcher_options,

        pageviewTrigger: pageview_trigger,

        visitTrigger: visit_trigger,
        visitTriggerOptions: visit_trigger_options,

        mobileInstallTrigger: mobile_install_trigger,
        mobileLaunchTrigger: mobile_launch_trigger
      }
    end

    def survey_data
      existing_image_options = AnswerImage.where(imageable_type: 'Account', imageable_id: @survey.account_id).map do |answer_image|
        { url: answer_image.image.url, id: answer_image.id }
      end

      invitation_diagram_properties = @survey.invitation_diagram_properties.where(user_id: @current_user.id).first_or_create do |record|
        record.position = @survey.invitation_diagram_properties.pick(:position)
        record.position ||= [10, 150]
      end

      thank_you_diagram_properties = @survey.thank_you_diagram_properties.where(user_id: @current_user.id).first_or_create do |record|
        record.position = @survey.thank_you_diagram_properties.pick(:position)
        record.position ||= [900, 150]
      end

      {
        invitation: @survey.invitation,
        invitationButton: @survey.invitation_button,
        invitationButtonDisabled: @survey.invitation_button_disabled,
        existingImageOptions: existing_image_options,
        thankYou: @survey.thank_you,
        pollEnabled: @survey.poll_enabled,

        thankYouDiagramProperties: {
          id: thank_you_diagram_properties.id,
          position: thank_you_diagram_properties.position
        },

        invitationDiagramProperties: {
          id: invitation_diagram_properties.id,
          position: invitation_diagram_properties.position
        },

        displayAllQuestions: @survey.display_all_questions
      }
    end

    def survey_list_survey_data(survey)
      @survey_list_survey_data ||= @current_user.account.surveys.
                                   joins(:questions).
                                   left_joins(questions: :possible_answers).
                                   pluck("surveys.id", "surveys.name", "questions.content", "possible_answers.content").
                                   each_with_object({}) do |(survey_id, survey_name, question_content, possible_answer_content), memo|
        memo[survey_id] ||= {
          type: "survey",
          name: survey_name,
          url: edit_survey_path(survey_id),
          id: survey_id,
          searchableContent: [survey_name, survey_id]
        }

        memo[survey_id][:searchableContent] << question_content if question_content.present?
        memo[survey_id][:searchableContent] << possible_answer_content if possible_answer_content.present?

        memo
      end

      @survey_list_survey_data[survey.id]
    end

    # Used by front end to build form parameters
    def self.html_attribute_map
      camel_case_attributes = %i(
        displayAllQuestions allAtOnceEmptyErrorEnabled allAtOnceSubmitLabel allAtOnceErrorText randomizeQuestionOrder
        surveyType themeId sdkThemeId customCss sdkWidgetHeight pusherEnabled fullscreenMargin positionType
        positionContent inlineTargetSelector mobileInlineTargetSelector sdkInlineTargetSelector inlineTargetPosition

        sampleRate desktopEnabled tabletEnabled mobileEnabled iosEnabled androidEnabled
        emailEnabled startsAt endsAt stopShowingWithoutAnswer ignoreFrequencyCap refireEnabled
        refireTime refireTimePeriod goal id

        typeCd triggerContent

        previousAnsweredSurveyId previousPossibleAnswerId

        renderAfterXSecondsEnabled renderAfterXSeconds

        renderAfterXPercentScrollEnabled renderAfterXPercentScroll

        renderAfterIntentExitEnabled

        renderAfterElementClickedEnabled renderAfterElementClicked

        renderAfterElementVisibleEnabled renderAfterElementVisible

        textOnPageEnabled textOnPageSelector textOnPagePresence textOnPageValue

        geoCountry geoStateOrDma

        clientKeyPresence

        deviceDataKey deviceDataMatcher deviceDataValue deviceDataMandatory

        pageviewsCount

        visitorType visitsCount

        mobileDaysInstalled

        mobileLaunchTimes

        surveyTagId

        brief
      )

      result = { appliedSurveyTagId: 'id' }

      camel_case_attributes.each do |camel_case_attribute|
        result[camel_case_attribute] = camel_case_attribute.to_s.underscore
      end

      result
    end

    private

    def compile_audit_changes(audit)
      case audit.action
      when "create"
        audit.audited_changes.map do |attribute, value|
          if (enum = get_enum(audit, attribute))
            value = enum[value]
          end

          { attribute => value.presence }
        end
      when "update"
        audit.audited_changes.map do |attribute, changed_values|
          if (enum = get_enum(audit, attribute))
            changed_values.map! { |val| enum[val] }
          end

          { attribute => changed_values }
        end.presence
      end
    end

    # We have a lot of data to specify
    def per_question_data(question, question_index)
      possible_answers_scope = question.possible_answers.sort_by_position
      possible_answer_data = possible_answers_scope.map do |possible_answer|
        {
          id: possible_answer.id,
          content: possible_answer.content,
          nextQuestionId: possible_answer.next_question_id,
          nextQuestionAllowed: question.question_type != 'multiple_choices_question' || possible_answer == possible_answers_scope.last,
          position: possible_answer.position,
          answerImageId: possible_answer.answer_image&.id,

          imageAlt: possible_answer.image_alt,
          imagePositionCd: possible_answer.image_position_cd,
          imageHeight: possible_answer.image_height,
          imageHeightMobile: possible_answer.image_height_mobile,
          imageHeightTablet: possible_answer.image_height_tablet,
          imageWidth: possible_answer.image_width,
          imageWidthMobile: possible_answer.image_width_mobile,
          imageWidthTablet: possible_answer.image_width_tablet
        }
      end

      next_question_column = question.free_text_question? ? 'free_text_next_question_id' : 'next_question_id'

      question_label = question.nps? ? 'NET PROMOTER SCORE' : QUESTION_TYPE_LABELS[question.question_type.to_sym]

      question_diagram_properties = question.diagram_properties.where(user_id: @current_user.id).first_or_create do |record|
        record.position = question.diagram_properties.pick(:position)
        record.position ||= [450 + (50 * question_index), 150 * (1 + question_index)]
      end

      {
        questionData: {
          id: question.id,
          type: { label: question_label, value: question.question_type },
          position: question.position,
          content: question.content,
          customContent: question.custom_content,
          nextQuestionId: question.free_text_next_question_id || question.next_question_id,
          nextQuestionColumn: next_question_column,
          nextQuestionAllowed: question.next_question_allowed?,
          nps: question.nps?,
          index: question_index,
          randomize: question.randomize,
          buttonType: question.button_type || 'radio',
          answersPerRowDesktop: question.answers_per_row_desktop,
          answersPerRowMobile: question.answers_per_row_mobile,
          singleChoiceDefaultLabel: question.single_choice_default_label,
          desktopWidthType: question.desktop_width_type,
          answersAlignmentDesktop: question.answers_alignment_desktop,
          mobileWidthType: question.mobile_width_type,
          answersAlignmentMobile: question.answers_alignment_mobile,
          beforeQuestionText: question.before_question_text,
          afterQuestionText: question.after_question_text,
          beforeAnswersCount: question.before_answers_count,
          afterAnswersCount: question.after_answers_count,
          beforeAnswersItems: question.before_answers_items,
          afterAnswersItems: question.after_answers_items,
          hintText: question.hint_text,
          submitLabel: question.submit_label,
          errorText: question.error_text,
          height: question.height,
          maxLength: question.max_length,
          maximumSelection: question.maximum_selection,
          enableMaximumSelection: question.enable_maximum_selection,
          emptyErrorText: question.empty_error_text,
          maximumSelectionsExceededErrorText: question.maximum_selections_exceeded_error_text,
          fullscreen: question.fullscreen,
          autocloseEnabled: question.autoclose_enabled,
          autocloseDelay: question.autoclose_delay,
          autoredirectEnabled: question.autoredirect_enabled,
          autoredirectDelay: question.autoredirect_delay,
          autoredirectUrl: question.autoredirect_url,
          showAfterAAO: question.show_after_aao,
          opacity: question.opacity,
          backgroundColor: question.background_color,
          imageSettings: question.image_settings,
          diagramProperties: {
            id: question_diagram_properties.id,
            position: question_diagram_properties.position
          },
          showAdditionalContent: question.show_additional_content,
          additionalContent: question.additional_content,
          additionalContentPosition: question.additional_content_position,
          sliderStartPosition: question.slider_start_position,
          sliderSubmitButtonEnabled: question.slider_submit_button_enabled,
          optional: question.optional
        },
        possibleAnswers: possible_answer_data
      }
    end
  end
end
