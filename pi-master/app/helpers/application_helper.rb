# frozen_string_literal: true
module ApplicationHelper
  # Set title for current page
  def title(page_title)
    content_for :title, page_title.to_s
  end

  # Set css scope for current page
  def css_scope(scope_name)
    content_for :css_scope, scope_name.to_s
  end

  def on_custom_card?
    params[:id].present? && current_page?(legacy_custom_card_survey_path)
  end

  def on_reporting?
    params[:id].present? && current_page?(report_survey_path)
  end

  def on_localization_editor?
    params[:survey_locale_group_id] && current_page?(localization_editor_path)
  end

  def on_editor?
    params[:id].present? && current_page?(edit_survey_path)
  end

  def on_link_builder?
    params[:id].present? && current_page?(url_builder_survey_path)
  end

  def on_localization_report?
    params[:survey_locale_group_id] && current_page?(localization_report_path)
  end

  def on_qrvey?
    current_page?(client_reports_qrvey_path)
  end

  def link_to_localization_results(survey_locale_group)
    if session[:from] && session[:to]
      link_to 'Results', localization_report_path(survey_locale_group, from: session[:from], to: session[:to])
    else
      link_to 'Results', localization_report_path(survey_locale_group)
    end
  end

  def datalayer_new_account_and_new_user
    current_page?(dashboard_path) && session[:from_invitation] == 'no'
  end

  def datalayer_new_user
    current_page?(dashboard_path) && session[:from_invitation] == 'yes'
  end

  def datalayer_user_login
    current_page?(dashboard_path) && session[:from_login] == 'yes'
  end

  def datalayer_push_js
    js = ''

    if datalayer_new_account_and_new_user
      js += "dataLayer.push({event: 'new_account'});"
    elsif datalayer_new_user
      js += "dataLayer.push({event: 'new_user'});"
    elsif datalayer_user_login
      js += "dataLayer.push({event: 'user_login'});"
    end

    js.html_safe
  end
end
