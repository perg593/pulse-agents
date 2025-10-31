# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

module Control
  class SurveysController < BaseController
    skip_before_action :verify_authenticity_token, only: :update
    before_action :set_survey, only: %i(ajax_report background_report_metrics background_report_stats change_status
                                        destroy duplicate edit free_text_answers page_event_data remove_background
                                        report survey_index_localization_modal trend_report_data update url_builder survey_deletion_modal legacy_custom_card localization_form_update)

    before_action :require_admin!, only: %i(destroy survey_deletion_modal)
    before_action :require_full_access_user!, except: %i(index report ajax_report free_text_answers background_report_metrics
                                                         background_report_stats localization_report_stats report
                                                         trend_report_data page_event_data localization_report edit)
    before_action :set_survey_locale_group, only: %i(localization_base_update localization_content_update localization_duplicate
                                                     localization_editor localization_report localization_report_metrics localization_report_stats
                                                     localization_update)

    before_action :set_base_survey, only: %i(localization_report)

    before_action :set_question, only: %i(page_event_data report)
    before_action :set_event, only: %i(report page_event_data)

    before_action :prevent_structural_changes_to_localized_survey, only: %i(update)

    after_action  :clean_flags, only: :index

    include DatesHelper
    include FiltersHelper
    include RedirectHelper
    include SQLHelpers

    CSS_SELECTOR_TRIGGERS = 0
    SURVEY_CSS = 1
    DOCKED_WIDGET_PLACEMENT = 2
    SURVEY_REFIRE = 3
    SURVEY_IMAGE = 4
    SURVEY_TAG = 5
    URL_TRIGGER = 6
    URL_SUPPRESSER = 7
    CUSTOM_DATA_TRIGGER = 8

    LOCALIZATION_MODALS = {
      CSS_SELECTOR_TRIGGERS => "css_selector_trigger_modal",
      SURVEY_CSS => "survey_css_modal",
      DOCKED_WIDGET_PLACEMENT => "survey_docked_widget_placement_modal",
      SURVEY_REFIRE => "survey_refire_modal",
      SURVEY_IMAGE => "survey_image_modal",
      SURVEY_TAG => "survey_tag_modal",
      URL_TRIGGER => "url_trigger_modal",
      URL_SUPPRESSER => "url_suppresser_modal",
      CUSTOM_DATA_TRIGGER => "custom_data_trigger_modal"
    }.freeze

    def index
      @surveys = current_user.surveys.includes(:applied_survey_tags).order('surveys.name')

      @audits = current_user.account.associated_audits.for_index(controller_name.classify).limit(10) if current_user.admin?

      date_range = parse_date_range(params[:from], params[:to])

      @presenter = SurveyIndexPresenter.new(@surveys, current_user, stored_filters, @audits, date_range)
    end

    def new
      @survey = Survey.new
    end

    def create
      @survey = current_user.account.surveys.new(edit_params)
      apply_survey_defaults(@survey)

      # TODO: Find another way of specifying this
      @survey.create_default_associations = true # Ensures defaults will be set after saving

      if @survey.save
        redirect_to edit_survey_url(@survey)
      else
        render :new, alert: "There was a problem saving the survey"
      end
    end

    def edit
      @render_breadcrumbs = true
      @presenter = SurveyEditPresenter.new(@survey, current_user, params[:openTabName])
    end

    def legacy_custom_card
      @question = Question.find(params[:question_id])
      @linkable_questions = (@survey.questions - [@question]).map { |q| [q.id, q.content] }

      render "control/surveys/localization/_custom_card"
    end

    def edit_params
      vetted_params = params.require(:survey).permit(
        :name,
        :invitation, :invitation_button, :invitation_button_disabled,
        :thank_you, :poll_enabled,
        :display_all_questions, :all_at_once_empty_error_enabled, :all_at_once_submit_label, :all_at_once_error_text, :randomize_question_order,
        :survey_type, :fullscreen_margin, :sdk_widget_height, :pusher_enabled,
        :inline_target_selector, :mobile_inline_target_selector, :sdk_inline_target_selector,
        :theme_id, :sdk_theme_id, :custom_css, :sample_rate,
        :position_type, :position_content,
        :desktop_enabled, :tablet_enabled, :mobile_enabled, :ios_enabled, :android_enabled, :email_enabled,
        :starts_at, :ends_at, :stop_showing_without_answer,
        :ignore_frequency_cap, :refire_enabled, :refire_time, :refire_time_period,
        :goal, :inline_target_position,
        {
          triggers_attributes: [
            :id, :type_cd, :trigger_content, :_destroy
          ],
          suppressers_attributes: [
            :id, :type_cd, :trigger_content, :_destroy
          ],
          answer_triggers_attributes: [
            :id, :previous_answered_survey_id, :previous_possible_answer_id, :_destroy
          ],
          page_after_seconds_trigger_attributes: [
            :id, :render_after_x_seconds, :render_after_x_seconds_enabled, :_destroy
          ],
          page_scroll_trigger_attributes: [
            :id, :render_after_x_percent_scroll, :render_after_x_percent_scroll_enabled, :_destroy
          ],
          page_intent_exit_trigger_attributes: [
            :id, :render_after_intent_exit_enabled
          ],
          page_element_clicked_trigger_attributes: [
            :id, :render_after_element_clicked_enabled, :render_after_element_clicked, :_destroy
          ],
          page_element_visible_trigger_attributes: [
            :id, :render_after_element_visible_enabled, :render_after_element_visible, :_destroy
          ],
          text_on_page_trigger_attributes: [
            :id, :text_on_page_enabled, :text_on_page_selector,
            :text_on_page_presence, :text_on_page_value, :_destroy
          ],
          geoip_triggers_attributes: [
            :id, :geo_country, :geo_state_or_dma, :_destroy
          ],
          client_key_trigger_attributes: [
            :id, :client_key_presence
          ],
          device_triggers_attributes: [
            :id, :device_data_key, :device_data_matcher, :device_data_value, :device_data_mandatory, :_destroy
          ],
          pageview_trigger_attributes: [
            :id, :pageviews_count
          ],
          visit_trigger_attributes: [
            :id, :visitor_type, :visits_count
          ],
          mobile_install_trigger_attributes: [
            :id, :mobile_days_installed
          ],
          mobile_launch_trigger_attributes: [
            :id, :mobile_launch_times
          ],
          invitation_diagram_properties_attributes: [
            :id, :_destroy,
            {
              position: []
            }
          ],
          thank_you_diagram_properties_attributes: [
            :id,
            {
              position: []
            }
          ],
          applied_survey_tags_attributes: [
            :id, :_destroy, :survey_tag_id
          ],

          last_survey_brief_job_attributes: [
            :id, :brief
          ],

          questions_attributes: [
            :id, :content, :next_question_id, :free_text_next_question_id, :_destroy,
            :ephemeral_id, :ephemeral_next_question_id, :ephemeral_free_text_next_question_id,
            :question_type, :nps, :randomize, :button_type, :answers_per_row_desktop, :answers_per_row_mobile,
            :single_choice_default_label, :mobile_width_type, :answers_alignment_mobile, :mobile_width_type, :answers_alignment_mobile,
            :desktop_width_type, :answers_alignment_desktop,
            :before_question_text, :after_question_text,
            :before_answers_count, :after_answers_count,
            :hint_text, :submit_label, :error_text, :empty_error_text, :height, :max_length,
            :maximum_selections_exceeded_error_text,
            :maximum_selection, :fullscreen, :autoclose_enabled, :autoclose_delay,
            :autoredirect_enabled, :autoredirect_delay, :autoredirect_url,
            :show_after_aao, :opacity, :background_color,
            :image_settings, :position, :custom_content, :enable_maximum_selection,
            :show_additional_content, :additional_content, :additional_content_position, :slider_start_position, :slider_submit_button_enabled,
            :optional,

            {
              before_answers_items: [],
              after_answers_items: [],

              diagram_properties_attributes: [
                :id,
                {
                  position: []
                }
              ],

              possible_answers_attributes: [
                :id,
                :content,
                :next_question_id,
                :ephemeral_next_question_id,
                :_destroy,
                :answer_image_id,
                :image_alt, :image_position_cd,
                :image_height, :image_height_mobile, :image_height_tablet,
                :image_width, :image_width_mobile, :image_width_tablet,
                :position
              ]
            }
          ]
        }
      )

      if param = vetted_params[:thank_you_diagram_properties_attributes]
        param[:user_id] = current_user.id
      end

      if param = vetted_params[:invitation_diagram_properties_attributes]
        param[:user_id] = current_user.id
      end

      if param = vetted_params[:questions_attributes]
        param.each_value do |attributes|
          if diagram_properties_attributes = attributes[:diagram_properties_attributes]
            diagram_properties_attributes[:user_id] = current_user.id
          end
        end
      end

      if triggers_attributes = vetted_params[:triggers_attributes]
        handle_trigger_type_changes(triggers_attributes)
      end

      vetted_params
    end

    def localization_form_update
      if @survey.update(localization_modal_params)
        flash.now.notice = "Survey was successfully updated."
      else
        flash.now.alert = @survey.errors.full_messages.join(",")
      end

      redirect_to localization_editor_path(@survey.survey_locale_group_id)
    end

    def update
      vetted_params = edit_params

      if @survey.update(vetted_params)
        @survey.reconcile_routing

        render json: {}, status: :ok
      else
        render json: { error: @survey.errors.full_messages.join(',') }, status: 500
      end
    end

    def destroy
      @survey.destroy

      error_message = "Failed to destroy survey. #{@survey.errors.full_messages.join('. ')}."

      if request.xhr?
        if @survey.destroyed?
          render json: {}, status: :ok
        else
          render json: { error: error_message }, status: 400
        end
      else
        notice = @survey.destroyed? ? "Survey was successfully destroyed." : error_message
        redirect_to surveys_url, notice: notice
      end
    end

    def background_report_stats
      reportee = @survey || @survey_locale_group

      filters = parse_filters(params)
      cache_available = filters.except(:date_range).blank? && reportee.submission_caches.exists?

      date_range = filters[:date_range]
      impression_count = cache_available ? reportee.cached_blended_impressions_count(date_range) : reportee.blended_impressions_count(filters: filters)
      submission_count = cache_available ? reportee.cached_submissions_count(date_range) : reportee.submissions_count(filters: filters)
      submission_rate = cache_available ? reportee.cached_submission_rate(date_range) : reportee.submission_rate(filters: filters)

      render status: :ok, json: {
        impression_count: helpers.number_with_delimiter(impression_count),
        submission_count: helpers.number_with_delimiter(submission_count),
        submission_rate: helpers.number_to_percentage(submission_rate * 100, precision: 0)
      }
    end
    alias localization_report_stats background_report_stats

    # Return impressions and submissions for plumbing lines and graphs
    def background_report_metrics
      render json: report_metrics, status: :ok
    end
    alias localization_report_metrics background_report_metrics

    def report
      @render_breadcrumbs = true
      @survey.free_text_analyze_async! if @survey.free_text?

      @show_page_event = params['show_page_event'] == 'true'

      filters = parse_filters(params)

      @presenter = SurveyReportPresenter.new(@survey, filters: filters, current_user: current_user)
      @page_event_presenter = PageEventPresenter.new(survey: @survey, question: @question, event: @event, filters: filters) if @show_page_event
      @report_job_presenter = presenter = ReportJobPresenter.new(current_user, survey: @survey)

      if current_user.account.qrvey_enabled?
        @qrvey_sidebar_presenter = QrveySidebarPresenter.new(@survey.id, current_user.id)
      end

      respond_to do |format|
        format.html
        format.js
      end
    end

    def localization_report
      @render_breadcrumbs = true
      @survey_edit_presenter = SurveyEditPresenter.new(@survey, current_user, "")

      @survey_locale_group.surveys.each { |survey| survey.free_text_analyze_async! if survey.free_text? }

      filters = parse_filters(params)

      @presenter = SurveyReportPresenter.new(@base_survey, survey_locale_group: @survey_locale_group, filters: filters, current_user: current_user)
      @report_job_presenter = ReportJobPresenter.new(current_user, survey_locale_group: @survey_locale_group)
    end

    # answer_id is 0 when a bar is unselected: we display everything
    def ajax_report
      filters = parse_filters(params)

      submissions = @survey.submissions
      submissions = Submission.filtered_submissions(submissions, filters: filters)

      ajax_report_data = {
        impression_sum: @survey.blended_impressions_count(filters: filters),
        submission_sum: submissions.count,
        submission_rate: @survey.human_submission_rate(filters: filters)
      }

      render json: {
        report: ajax_report_data,
        report_data: report_metrics,
        result: answer_counts_per_question(submissions, filters: filters)
      }
    end

    def duplicate
      handle_duplication(@survey, dashboard_url)
    end

    def free_text_answers
      @text = params[:text] || ''
      @limit = 50

      @question = @survey.questions.find(params[:question_id])
      if @question
        sql = "keyword_extraction @> '[{\"text\":\"#{ActiveRecord::Base.connection.quote(@text)[1..-2]}\"}]'"
        sanitized_sql_statement = ActiveRecord::Base.send(:sanitize_sql_array, [sql])
        query = @question.answers.where(sanitized_sql_statement)
        @answers = query.limit(@limit).all
        @answers_count = query.count
      else
        @answers = []
        @answers_count = 0
      end
      respond_to do |format|
        format.html { render layout: false }
      end
    end

    def url_builder
      respond_to(&:html)
    end

    def change_status
      @survey.update!(status: params[:status])

      redirect_to dashboard_path
    end

    def live_preview
      url = params[:user][:live_preview_url]

      url = "https://#{url[7..]}" if url =~ /^http:\/\//
      url = "https://#{url}" unless url =~ /^https:\/\//

      current_user.update_attribute(:live_preview_url, url)

      survey_id = params[:user][:survey_id]

      url += (url.include?("?") ? "&" : "?") + "pi_live_preview=true&pi_present=#{survey_id}"

      redirect_to url, allow_other_host: true
    end

    def remove_background
      @survey.remove_background!
      @survey.remove_background = true
      @survey.save

      redirect_to localization_editor_path(@survey.survey_locale_group_id), notice: "Background image was successfully deleted."
    end

    def localization_editor; end

    def localization_duplicate
      handle_duplication(@survey_locale_group.base_survey, :localization_editor)
    end

    # AJAX
    # Content changes are applied to all surveys in the survey_locale_group with the same language_code
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize
    def localization_content_update
      unless survey = @survey_locale_group.surveys.find_by(id: params[:survey_id])
        redirect_to dashboard_path and return
      end

      survey_ids = if survey.language_code.present?
        @survey_locale_group.surveys.where(language_code: survey.language_code).pluck(:id)
      else
        Array.wrap(survey.id)
      end

      if question_id = params.dig(:survey, :questions_attributes, :id)
        question_locale_group_id = Question.find(question_id).question_locale_group_id
        question_scope = Question.where(survey_id: survey_ids, question_locale_group_id: question_locale_group_id)

        if new_question_content = params.dig(:survey, :questions_attributes, :content)
          question_scope.each do |question|
            question.update(content: new_question_content)
          end
        elsif possible_answer_id = params.dig(:survey, :questions_attributes, :possible_answers_attributes, :id)
          possible_answer_locale_group_id = PossibleAnswer.find(possible_answer_id).possible_answer_locale_group_id

          if new_possible_answer_content = params.dig(:survey, :questions_attributes, :possible_answers_attributes, :content)
            question_ids = question_scope.pluck(:id)

            PossibleAnswer.where(question_id: question_ids, possible_answer_locale_group_id: possible_answer_locale_group_id).each do |possible_answer|
              possible_answer.update(content: new_possible_answer_content)
            end
          end
        end
      end

      locale_group_survey_params = localization_content_update_params

      unless locale_group_survey_params.empty?
        Survey.where(id: survey_ids).each do |survey_to_update|
          survey_to_update.update(locale_group_survey_params)
        end
      end

      render json: {}, status: :ok
    end

    # AJAX
    # Some updates made to base surveys will be applied to all surveys in
    # the same survey_locale_group.
    def localization_base_update
      vetted_params = localization_base_update_params
      survey_scope = @survey_locale_group.surveys

      if (trigger_attributes = localization_trigger_attributes).present?
        Trigger.where(type_cd: trigger_attributes[:type_cd], survey_id: survey_scope.pluck(:id)).each do |trigger|
          trigger.update(trigger_attributes.except(:type_cd))
        end

        render json: {}, status: :ok
      elsif vetted_params.empty?
        render json: :forbidden, status: 404
      else
        survey_scope.each { |survey| survey.update(vetted_params) }
        render json: {}, status: :ok
      end
    end

    # AJAX
    def localization_update
      unless survey = @survey_locale_group.surveys.find_by(id: params[:survey_id])
        redirect_to dashboard_path and return
      end

      if params[:survey]
        handle_localization_trigger_attributes

        if request_changes_survey_name?(survey) && !current_user.admin?
          error_message = "Only administrators may change survey names"

          render json: { error: error_message }, status: 403 and return
        end

        unless survey.update(params.require(:survey).permit(localization_params))
          render json: :internal_error, status: 500 and return
        end

        apply_locale_routing(survey)
      end

      if params[:applied_survey_tags]
        @survey = survey
        update_tags

        render json: { tags: survey.applied_survey_tag_names }, status: :ok and return
      end

      render json: {}, status: :ok
    end

    def localization_editor_survey_modal
      modal_partial = LOCALIZATION_MODALS[params[:modal_partial].to_i]

      unless modal_partial && survey = current_user.account.surveys.find_by(id: params[:survey_id])
        render json: :forbidden, status: 404 and return
      end

      render partial: "control/surveys/localization/#{modal_partial}", locals: { modal_id: params[:modal_id], survey: survey }
    end

    def survey_index_localization_modal
      render partial: "control/surveys/localization/survey_index_localization_modal", locals: { modal_id: params[:modal_id], survey: @survey }
    end

    def survey_deletion_modal
      render partial: "control/surveys/survey_deletion_modal", locals: { survey: @survey }
    end

    # Changes to surveys.name require administrator privileges
    def inline_edit
      survey = current_user.account&.surveys&.find_by(id: params[:id])
      render json: :forbidden, status: 404 and return unless survey

      whitelisted_params = params.require(:survey).permit([:name, :status, :goal])

      if whitelisted_params[:name] && !current_user.admin?
        render json: {}, status: :forbidden and return
      end

      survey.update(whitelisted_params)

      if survey.errors.empty?
        render json: {}, status: :ok
      else
        render json: {}, status: :bad_request
      end
    end

    def trend_report_data
      filters = parse_filters(params)

      presenter = SurveyReportPresenter.new(
        @base_survey || @survey,
        survey_locale_group: @survey_locale_group, filters: filters, current_user: current_user
      )

      render json: presenter.trend_report_params, status: :ok
    end

    def page_event_data
      presenter = PageEventPresenter.new(survey: @survey, question: @question, event: @event, filters: parse_filters(params))
      render json: presenter.item_update_params, status: :ok
    end

    private

    # When we change a trigger's type_cd, we continue to run the old type's validations and callbacks, when we want to run the new ones.
    # This is complicated, so let's just destroy the old trigger and create a new one.
    # The new trigger will have the correct validations and callbacks executed.
    def handle_trigger_type_changes(triggers_attributes)
      to_add = []

      triggers_attributes.each_value do |trigger_attributes|
        next unless trigger_attributes[:id].present?
        next unless trigger = @survey.triggers.find(trigger_attributes[:id])
        next unless trigger.type_cd != trigger_attributes[:type_cd]

        trigger_attributes[:_destroy] = 1

        to_add << trigger_attributes.except(:id, :_destroy)
      end

      return unless to_add.present?

      highest_index = triggers_attributes.keys.map(&:to_i).max

      to_add.each do |trigger_attributes|
        triggers_attributes[(highest_index + 1).to_s] = trigger_attributes

        highest_index += 1
      end
    end

    def request_changes_survey_name?(survey)
      params[:survey].key?(:name) && params[:survey][:name] != survey.name
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_changes_routing?(vetted_params)
      return false unless vetted_params[:questions_attributes]

      question_routing_changed = vetted_params[:questions_attributes].to_h.any? do |_index_key, attributes|
        question = @survey.questions.find(attributes[:id])

        question.next_question_id.to_s != attributes[:next_question_id].presence.to_s ||
          question.free_text_next_question_id.to_s != attributes[:free_text_next_question_id].presence.to_s
      end

      possible_answer_routing_changed = vetted_params[:questions_attributes]&.to_h&.any? do |_index_key, attributes|
        attributes[:possible_answers_attributes]&.any? do |_index_key, possible_answer_attributes|
          possible_answer = @survey.possible_answers.find(possible_answer_attributes[:id])

          possible_answer.next_question_id.to_s != possible_answer_attributes[:next_question_id].presence.to_s
        end
      end

      return question_routing_changed || possible_answer_routing_changed
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_changes_all_at_once_mode?(vetted_params)
      return false unless vetted_params

      vetted_params.key?(:display_all_questions) && vetted_params[:display_all_questions] != @survey.display_all_questions.to_s
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_changes_randomize_question_order?(vetted_params)
      return false unless vetted_params

      vetted_params.key?(:randomize_question_order) && vetted_params[:randomize_question_order] != @survey.randomize_question_order.to_s
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_changes_questions_randomize?(vetted_params)
      return false unless vetted_params

      vetted_params[:questions_attributes].to_h.any? do |_index_key, question_attributes|
        question = @survey.questions.find_by(id: question_attributes[:id])
        next unless question

        question_attributes.key?(:randomize) && question_attributes[:randomize] != question.randomize.to_s
      end
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_adds_questions?(vetted_params)
      return false unless vetted_params[:questions_attributes]

      vetted_params[:questions_attributes].to_h.any? do |_index_key, question_attributes|
        question_attributes[:id].nil?
      end
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_adds_possible_answers?(vetted_params)
      return false unless vetted_params[:questions_attributes]

      vetted_params[:questions_attributes].to_h.any? do |_index_key, attributes|
        attributes[:possible_answers_attributes]&.any? do |_index_key, possible_answer_attributes|
          possible_answer_attributes[:id].nil?
        end
      end
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_repositions_questions?(vetted_params)
      return false unless vetted_params[:questions_attributes]

      vetted_params[:questions_attributes].to_h.any? do |_index_key, question_attributes|
        question = @survey.questions.find_by(id: question_attributes[:id])
        next unless question

        question.position.to_s != question_attributes[:position].presence
      end
    end

    # TODO: This validation should probably be done at the model level
    # Do it when validates_associated works for surveys and questions
    def request_repositions_possible_answers?(vetted_params)
      return false unless vetted_params[:questions_attributes]

      vetted_params[:questions_attributes]&.to_h&.any? do |_index_key, attributes|
        attributes[:possible_answers_attributes]&.any? do |_index_key, possible_answer_attributes|
          possible_answer = @survey.possible_answers.find(possible_answer_attributes[:id])
          possible_answer.position.to_s != possible_answer_attributes[:position].presence
        end
      end
    end

    def filtered_survey_metrics(data, filters)
      submission_scope = (@survey || @survey_locale_group).impressions
      account = (@survey || @survey_locale_group).account

      result = Submission.filtered_submissions(submission_scope, filters: filters).select(<<-SQL).group('creation_date').order('creation_date')
        DATE(submissions.created_at) creation_date,
        COUNT(CASE WHEN answers_count > 0 THEN 1 END) submission_sum,
        CASE
          WHEN #{ActiveRecord::Base.sanitize_sql(['DATE(submissions.created_at) < ?', account.viewed_impressions_calculation_start_at])}
            THEN COUNT(submissions.id)
          ELSE COUNT(submissions.viewed_at)
        END impression_sum,
        CASE
          WHEN #{ActiveRecord::Base.sanitize_sql(['DATE(submissions.created_at) < ?', account.viewed_impressions_calculation_start_at])}
            THEN CASE
              WHEN COUNT(submissions.id) = 0
                THEN 0
              ELSE ROUND(COUNT(CASE WHEN answers_count > 0 THEN 1 END) / COUNT(submissions.id)::DECIMAL, 2)
            END
          ELSE CASE
            WHEN COUNT(submissions.viewed_at) = 0
              THEN 0
            ELSE ROUND(COUNT(CASE WHEN answers_count > 0 THEN 1 END) / COUNT(submissions.viewed_at)::DECIMAL, 2)
          END
        END rate
      SQL

      %i(impression_sum submission_sum rate).each { |key| data = mapping_for_chartjs(key, data, result) }
      data
    end

    # TODO: Merge this with SQLHelpers#date_range_filter
    def submissions_date_filter_sql(date_range)
      return true unless date_range

      <<-SQL
        submissions.created_at BETWEEN '#{PG::Connection.escape(date_range.first.utc.to_s)}' AND '#{PG::Connection.escape(date_range.last.utc.to_s)}'
      SQL
    end

    def unfiltered_survey_metrics(data)
      data_per_timestamp = {}

      survey_metrics_cache_scope.group(:applies_to_date).order(:applies_to_date).pluck(
        Arel.sql(<<~SQL)
          applies_to_date,
          SUM(submission_count),
          SUM(viewed_impression_count),
          SUM(impression_count) served_impression_count
        SQL
      ).each do |date, submission_count, viewed_impression_count, served_impression_count|
        impression_count =
          if current_user.account.viewed_impressions_calculation_start_at <= date
            viewed_impression_count.to_f
          else
            served_impression_count.to_f
          end
        submission_rate = submission_count/impression_count.round(2)

        timestamp = date.to_datetime.to_i * 1000
        data_per_timestamp[timestamp] = {
          impressions: impression_count,
          submissions: submission_count.to_f,
          submission_rate: submission_rate
        }
      end

      data_per_timestamp.each do |timestamp, single_day_data|
        data[:impression_sum] << [timestamp, single_day_data[:impressions]]
        data[:submission_sum] << [timestamp, single_day_data[:submissions]]
        data[:rate] << [timestamp, single_day_data[:submission_rate]]
      end

      data
    end

    def report_survey_ids
      if @survey_locale_group
        @survey_locale_group.survey_ids
      elsif @survey
        [@survey.id]
      end
    end

    def survey_metrics_cache_scope
      cache_scope = SurveySubmissionCache.where(survey_id: report_survey_ids)
      cache_scope = cache_scope.where(applies_to_date: @date_range) if @date_range
      cache_scope
    end

    def localization_trigger_attributes
      result = {}

      if trigger_params = params[:survey][:pageview_trigger_attributes]
        result[:type_cd] = "pageview"
        result[:pageviews_count] = trigger_params[:pageviews_count]
      elsif trigger_params = params[:survey][:visit_trigger_attributes]
        result[:type_cd] = "visit"
        result[:visitor_type] = trigger_params[:visitor_types]
      end

      result
    end

    def localization_base_update_params
      params_whitelist = [
        :status, :goal, :theme_id, :display_all_questions, :randomize_question_order,
        :desktop_enabled, :tablet_enabled, :mobile_enabled, :email_enabled,
        :starts_at, :ends_at, :ignore_frequency_cap, :poll_enabled,
        :stop_showing_without_answer, :sample_rate
      ]

      params.require(:survey).permit(params_whitelist)
    end

    def localization_content_update_params
      params_whitelist = [:invitation, :invitation_button, :all_at_once_submit_label, :all_at_once_error_text, :invitation, :thank_you]

      result = params.require(:survey).permit(params_whitelist)
      result[:invitation_button_disabled] = result.key?(:invitation_button) && result[:invitation_button].nil?

      result
    end

    def localization_params
      survey_specific_params = [:goal, :desktop_enabled, :tablet_enabled, :mobile_enabled, :theme_id, :sample_rate, :ignore_frequency_cap, :status, :survey_type, :display_all_questions, :all_at_once_empty_error_enabled, :randomize_question_order, :email_enabled, :starts_at, :ends_at, :stop_showing_without_answer, :poll_enabled, :name, :inline_target_selector, :mobile_inline_target_selector, :inline_target_position, :sdk_inline_target_selector, :pusher_enabled, :language_code, :locale_code, :thank_you, :all_at_once_submit_label, :all_at_once_error_text]

      associated_model_params = [
        {
          page_scroll_trigger_attributes: [:render_after_x_percent_scroll, :render_after_x_percent_scroll_enabled]
        },
        {
          page_after_seconds_trigger_attributes: [:render_after_x_seconds, :render_after_x_seconds_enabled]
        },
        {
          pageview_trigger_attributes: [:pageviews_count]
        },
        {
          questions_attributes: [
            :id, :content, :randomize, :before_question_text, :after_question_text,
            :hint_text, :submit_label, :question_type,
            :question_locale_group_id, :error_text, :enable_maximum_selection, :maximum_selection,
            :empty_error_text, :maximum_selections_exceeded_error_text,
            :show_additional_content, :additional_content, :additional_content_position,
            {
              possible_answers_attributes: [:id, :content, :possible_answer_locale_group_id]
            }
          ]
        },
        {
          visit_trigger_attributes: [:visitor_type]
        }
      ]

      survey_specific_params + associated_model_params
    end

    def handle_localization_trigger_attributes
      # TBD whether blank should disable trigger
      if page_scroll_trigger_attributes = params[:survey][:page_scroll_trigger_attributes]
        page_scroll_trigger_attributes[:render_after_x_percent_scroll_enabled] = page_scroll_trigger_attributes[:render_after_x_percent_scroll].present?
      end

      return unless page_after_seconds_trigger_attributes = params[:survey][:page_after_seconds_trigger_attributes]

      page_after_seconds_trigger_attributes[:render_after_x_seconds_enabled] = page_after_seconds_trigger_attributes[:render_after_x_seconds].present?
    end

    def set_survey_locale_group
      @survey_locale_group = current_user.account.survey_locale_groups.find_by(id: params[:survey_locale_group_id])

      handle_missing_record unless @survey_locale_group
    end

    def set_base_survey
      @base_survey = @survey_locale_group.base_survey
    end

    def handle_duplication(survey, redirect_location)
      duplicated_survey = survey.duplicate

      if duplicated_survey.save
        duplicated_survey.survey_stat.update(answers_count: 0)
        duplicated_survey.reattach_plumbing_lines(survey)

        if request.xhr?
          @presenter = SurveyIndexPresenter.new(Survey.where(id: survey.id), current_user, [], [], nil)
          render json: { newSurvey: @presenter.survey_data_for_table(duplicated_survey)}, status: :ok
        else
          redirect_to redirect_location, notice: 'Survey was successfully duplicated.'
        end
      elsif request.xhr?
        render json: {}, status: 500
      else
        flash.alert = duplicated_survey.errors.full_messages.join(',')
        redirect_to redirect_location
      end
    end

    def set_survey
      @survey = current_account&.surveys&.find_by(id: params[:id])

      handle_missing_record unless @survey
    end

    def set_question
      @question = @survey.questions.find_by(id: params['question_id']) if params['question_id'].present?
    end

    def set_event
      @event = current_account.page_events.find_by(name: params['page_event_name']) if params['page_event_name'].present? # TODO: https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2142
    end

    def localization_modal_params
      vetted_params = params.require(:survey).permit(
        :position_type, :position_content,
        :top_position, :bottom_position, :right_position, :left_position, :background_color, :text_color,
        :inline_position, :width, :custom_css, :invitation,
        :refire_enabled, :refire_time_period, :refire_time, :background, :remote_background,
        :invitation_button, :invitation_button_disabled,
        {triggers_attributes: [:id, :type_cd, :trigger_content, :_destroy]},
        {suppressers_attributes: [:id, :type_cd, :trigger_content, :_destroy]},
        {device_triggers_attributes: [:id, :device_data_key, :device_data_matcher, :device_data_value, :device_data_mandatory, :_destroy]},
        {page_element_clicked_trigger_attributes: [:id, :render_after_element_clicked, :render_after_element_clicked_enabled]},
        {page_element_visible_trigger_attributes: [:id, :render_after_element_visible, :render_after_element_visible_enabled]},
        {text_on_page_trigger_attributes: [:id, :text_on_page_enabled, :text_on_page_selector, :text_on_page_presence, :text_on_page_value]},
        {client_key_trigger_attributes: [:id, :client_key_presence]}
      )

      vetted_params = handle_triggers_attributes(vetted_params)
      vetted_params = handle_suppressers_attributes(vetted_params)
      handle_device_triggers_attributes(vetted_params)
    end

    def handle_triggers_attributes(params_data)
      # Ignore the creation of empty trigger attributes
      return params_data unless params_data[:triggers_attributes]

      params_data[:triggers_attributes].delete_if { |_k, v| v[:trigger_content].blank? && v[:id].nil? }

      # Delete the blank ones when update triggers
      params_data[:triggers_attributes].transform_values do |v|
        v['_destroy'] = '1' if v['id'].present? && v['trigger_content'].blank?
      end

      params_data
    end

    def handle_suppressers_attributes(params_data)
      # Ignore the creation of empty suppressers attributes
      return params_data unless params_data[:suppressers_attributes]

      params_data[:suppressers_attributes].delete_if { |_k, v| v[:id].nil? && v[:trigger_content].blank? }
      # Delete the blank ones when update triggers
      params_data[:suppressers_attributes].transform_values do |v|
        v['_destroy'] = '1' if v['id'].present? && v['trigger_content'].blank?
      end

      params_data
    end

    def handle_device_triggers_attributes(params_data)
      # Ignore the creation of empty device triger attributes
      return params_data unless params_data[:device_triggers_attributes]

      params_data[:device_triggers_attributes].delete_if { |_k, v| v[:device_data_key].blank? && v[:id].nil? }
      # Delete the blank ones when update device triggers
      params_data[:device_triggers_attributes].transform_values do |v|
        v['_destroy'] = '1' if v['id'].present? && v['device_data_key'].blank?
      end

      params_data
    end

    def no_redirect?
      %w(Save Update).include?(params[:commit])
    end

    def report_stats
      filters = parse_filters(params)

      {
        impression_count: helpers.number_with_delimiter(@survey.blended_impressions_count(filters: filters)),
        submission_count: helpers.number_with_delimiter(@survey.submissions_count(filters: filters)),
        submission_rate:  helpers.number_to_percentage(@survey.submission_rate(filters: filters) * 100, precision: 0)
      }
    end

    def report_metrics
      filters = parse_filters(params)

      data = {
        impression_sum: [],
        submission_sum: [],
        rate: []
      }

      if filters.blank? && SurveySubmissionCache.where(survey_id: report_survey_ids).exists?
        unfiltered_survey_metrics(data)
      else
        filtered_survey_metrics(data, filters)
      end
    end

    def submissions_survey_filter_sql(market_ids)
      survey_ids = if market_ids
        market_ids
      elsif @survey_locale_group
        @survey_locale_group.survey_ids
      elsif @survey
        [@survey.id]
      end

      return true unless survey_ids

      <<-SQL
        submissions.survey_id IN (#{survey_ids.join(', ')})
      SQL
    end

    def mapping_for_chartjs(key, data, results)
      data[key] = results.map do |row|
        # DateTime.to_i is in seconds, Highcharts needs it javascript style (ms)
        timestamp = row["creation_date"].to_datetime.to_i * 1000
        [timestamp, row[key.to_s].to_f]
      end

      data
    end

    def answer_counts_per_question(submissions, filters: {})
      possible_answer_id = filters[:possible_answer_id].to_i
      submission_ids = possible_answer_id.zero? ? [] : submissions.ids
      @survey.questions.map { |question| question.filtered_answers_count(submission_ids, filters: filters) }
    end

    def clean_flags
      session.delete(:from_invitation)
      session.delete(:from_login)
    end

    def update_tags
      survey_tag_names, survey_tag_ids = params[:applied_survey_tags].partition { |val| val.to_i.to_s != val } if params[:applied_survey_tags].present?

      if survey_tag_ids.blank?
        AppliedSurveyTag.where(survey: @survey).destroy_all
      else
        survey_tag_ids.map!(&:to_i)
        AppliedSurveyTag.where(survey: @survey).where.not(survey_tag_id: survey_tag_ids).destroy_all

        existing_applied_survey_tag_ids = AppliedSurveyTag.where(survey: @survey).pluck(:survey_tag_id)
        survey_tag_ids.reject { |survey_tag_id| existing_applied_survey_tag_ids.include? survey_tag_id.to_i }.each do |survey_tag_id|
          AppliedSurveyTag.create(survey_tag_id: survey_tag_id, survey: @survey)
        end
      end

      survey_tag_names&.each do |survey_tag_name|
        new_survey_tag = SurveyTag.create(name: survey_tag_name, account: @survey.account)
        AppliedSurveyTag.create(survey_tag: new_survey_tag, survey: @survey)
      end
    end

    def apply_locale_routing(survey)
      return unless params.dig(:survey, :questions_attributes, "0", :possible_answers_attributes)

      survey.possible_answers.each(&:apply_locale_group_routing)

      survey.questions.multiple_choices_question.includes(:possible_answers).each do |multiple_choices_question|
        multiple_choices_question.possible_answers.second_to_last.update(next_question_id: nil)
      end
    end

    def stored_filters
      return [] unless params[:filters]

      filter_params = [
        :nameID,
        { statusID: [], tagsID: [], createdByNameID: [], editedByID: [], lastChangeID: [] }
      ]

      vetted_params = params[:filters].permit(filter_params)

      return vetted_params.to_h.map do |key, value|
        {
          id: key,
          value: value
        }
      end
    end

    def apply_survey_defaults(survey)
      survey.thank_you = CUSTOMS[:survey][:thank_you]
      survey.first_question_attributes = {
        survey: survey,
        position: 0,
        content: CUSTOMS[:survey][:first_question][:content],
        possible_answers_attributes: CUSTOMS[:survey][:first_question][:possible_answers].map { |x| {content: x} }
      }
      survey.follow_up_questions_attributes = CUSTOMS[:survey][:follow_up_questions].map do |x|
        {
          survey: survey,
          position: x[:position],
          content: x[:content],
          possible_answers_attributes: x[:possible_answers].map { |y| {content: y} }
        }
      end
    end

    # We've got a lot of things to check
    # rubocop:disable Metrics/PerceivedComplexity
    def prevent_structural_changes_to_localized_survey
      return unless @survey.localized?

      vetted_params = edit_params

      if request_changes_all_at_once_mode?(vetted_params)
        error_message = "Cannot change display_all_questions for localized survey. Please use the localization (bulk) editor"
        render json: { error: error_message }, status: 400 and return
      end

      if request_changes_randomize_question_order?(vetted_params)
        error_message = "Cannot change randomize_question_order for localized survey. Please use the localization (bulk) editor"
        render json: { error: error_message }, status: 400 and return
      end

      if request_changes_questions_randomize?(vetted_params)
        error_message = "Cannot change possible answer randomization for localized survey. Please use the localization (bulk) editor"
        render json: { error: error_message }, status: 400 and return
      end

      if request_adds_questions?(vetted_params)
        error_message = "Cannot create question for localized survey. Please use the localization (bulk) editor to add the question"
        render json: { error: error_message }, status: 400 and return
      end

      if request_repositions_questions?(vetted_params)
        error_message = "Cannot change question position for localized survey."
        render json: { error: error_message }, status: 400 and return
      end

      if request_adds_possible_answers?(vetted_params)
        error_message = "Cannot create possible answer for localized survey. Please use the localization (bulk) editor to add the possible answer"
        render json: { error: error_message }, status: 400 and return
      end

      if request_repositions_possible_answers?(vetted_params)
        error_message = "Cannot change possible answer position for localized survey."
        render json: { error: error_message }, status: 400 and return
      end

      return unless request_changes_routing?(vetted_params)

      error_message = "Cannot change routing for localized survey."
      render json: { error: error_message }, status: 400 and return
    end
  end
end
