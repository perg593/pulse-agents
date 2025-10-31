# frozen_string_literal: true
module Control
  module QrveyHelper
    def on_qrvey_account_report_page?
      action_name == "client_reports" && @survey_id.nil?
    end

    def client_reports_subnav_links
      links = @survey.nil? ? [] : subnav_links

      client_report_link = {
        url: client_reports_qrvey_path(survey_id: @survey&.id, dashboard_id: @dashboard_id, mode: "view"),
        name: "view_report"
      }
      dashboard_name = @qrvey_sidebar_presenter.current_dashboard_name

      client_report_link[:label] = if @survey.nil?
        "<span class='report-category'>Account Reports</span>: #{dashboard_name}"
      else
        "<span class='report-category'>#{@qrvey_sidebar_presenter.current_dashboard_group_name}</span>: #{dashboard_name}"
      end

      links << client_report_link

      links
    end
  end
end
