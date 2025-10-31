# frozen_string_literal: true

module Control
  module SurveysHelper
    def survey_statuses_for_select
      Survey.statuses.without('live').keys.sort.map { |x| [x.titleize, x] }.insert(4, %w(Live live)).insert(4, ['─────', nil])
    end

    def survey_type_options
      Survey.survey_types.keys.map { |survey_type| [survey_type.titleize, survey_type] }
    end

    # For report page ==========================================================
    def themes_for_survey(type)
      return [['Default', nil]] unless account = @survey&.account || @survey_locale_group&.account

      themes = account.themes.order('updated_at DESC')
      themes = themes.where(theme_type: type) if %i(css native).include?(type)
      themes.pluck(:name, :id).unshift(['Default', nil])
    end

    def print_tooltip(base_survey_name, base_survey_value, current_value)
      title = "#{base_survey_name}: #{base_survey_value || "null"}"
      hidden = base_survey_value == current_value
      tag_class = "glyphicon glyphicon-info-sign diff-tooltip #{"hidden" if hidden}"

      content_tag(:span, nil, class: tag_class, data: { toggle: 'tooltip', placement: 'right' }, title: title)
    end

    def compare_and_print_tooltip(base_survey, current_survey, field, base_value = nil)
      current_value = current_survey.send(field)
      print_tooltip(base_survey.name, base_value || base_survey.send(field), current_value)
    end

    def print_translation_tooltip(record, column)
      return unless record && column

      tag_class = "glyphicon glyphicon-globe translation-tooltip #{"hidden" if record.send(column).blank?}"
      lookup_url = locale_translation_caches_look_up_path(record_id: record.id, record_type: record.class.name, column: column)

      content_tag(:span, nil, class: tag_class, data: { toggle: 'tooltip', placement: 'right' }, title: "", href: lookup_url)
    end

    def localization_cell_endpoint(survey_locale_group_id, _base_survey_id, survey_id)
      localization_update_path(survey_locale_group_id, survey_id: survey_id)
      # if survey_id == base_survey_id
      #   localization_base_update_path(survey_locale_group_id)
      # else
      #   localization_update_path(survey_locale_group_id, survey_id: survey_id)
      # end
    end

    def created_by_name(survey, is_admin: false)
      if audit = survey.audits&.creates&.first
        print_username(audit, is_admin: is_admin)
      else
        survey.account.primary_user.name
      end
    end

    def subnav_links(is_admin: false)
      links = [
        {
          url: @survey_locale_group ? localization_editor_path(@survey_locale_group) : edit_survey_path(@survey),
          label: 'Edit',
          name: 'edit'
        },
        {
          url: @survey_locale_group ? url_builder_survey_path(@base_survey) : url_builder_survey_path(@survey),
          label: 'Link Builder',
          name: 'url_builder'
        }
      ]

      links << report_subnav_link unless on_qrvey?

      if is_admin
        links << {
          url: troubleshoot_admin_surveys_path(survey_id: @survey&.id || @base_survey.id),
          label: "Troubleshooter",
          name: "troubleshooter"
        }

        links << {
          url: pdf_template_admin_surveys_path(survey_id: @survey&.id || @base_survey.id),
          label: "PDF Template",
          name: "pdf_template"
        }
      end

      links
    end

    def report_subnav_link
      report_url = @survey_locale_group ? localization_report_path(@survey_locale_group) : report_survey_path(@survey)
      page_event_url = @survey_locale_group ? '#' : report_survey_path(@survey, show_page_event: true)

      top_level_label = on_editor? || on_link_builder? ? "Results" : "<b>Results:</b> Overview"

      # Displays the page event url only when it's reporting page and there are relevant page_event data - 1 question and 1 event minimum
      if on_reporting? && page_event_data_exist?
        {
          popupLinks: [{ url: report_url, label: "Results" }, { url: page_event_url, label: 'Event Occurrence' }],
          subNavLabel: top_level_label,
          name: 'report'
        }
      else
        { url: report_url, label: top_level_label, name: 'report' }
      end
    end

    def page_event_data_exist?
      @survey.questions.where(question_type: %i(single_choice_question multiple_choices_question)).exists? && @survey.account.page_events.exists?
    end
  end
end
