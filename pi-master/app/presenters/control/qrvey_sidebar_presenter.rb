# frozen_string_literal: true

module Control
  class QrveySidebarPresenter
    include Rails.application.routes.url_helpers

    def initialize(survey_id, current_user_id, current_dashboard_id = nil)
      @account = User.find(current_user_id).account
      @survey_id = survey_id
      @current_dashboard_id = current_dashboard_id
      @current_user_id = current_user_id

      @qrvey_response = request_data_from_qrvey
    end

    def links
      {
        builtIn: built_in_dashboard_links,
        sharedWithMe: shared_with_me_dashboard_links,
        myReports: my_dashboard_links
      }
    end

    def share_options
      users = @account.users.where.not(id: @current_user_id)

      options = {}

      @qrvey_response&.each do |qrvey_dashboard_response|
        qrvey_dashboard_id = qrvey_dashboard_response.dashboard_id

        options[qrvey_dashboard_id] = users.map do |user|
          shared = qrvey_dashboard_response.dashboard_shared_with_user?(user.id)
          access_level = qrvey_dashboard_response.user_access_level(user.id)

          {
            userId: user.id,
            userName: user.first_name,
            shared: shared,
            permissions: access_level
          }
        end
      end

      { options: options }
    end

    def authorization
      authorization_per_dashboard = {}

      @qrvey_response&.each do |qrvey_dashboard_response|
        qrvey_dashboard_id = qrvey_dashboard_response.dashboard_id

        authorization_per_dashboard[qrvey_dashboard_id] = {
          canDelete: qrvey_dashboard_response.can_delete?(@current_user_id),
          canShare: qrvey_dashboard_response.can_share?(@current_user_id),
          canCopy: qrvey_dashboard_response.can_copy?(@current_user_id),
          canEdit: qrvey_dashboard_response.can_edit?(@current_user_id)
        }
      end

      authorization_per_dashboard
    end

    def using_hardcoded_defaults?
      !using_qrvey?
    end

    def current_dashboard
      return nil if using_hardcoded_defaults?

      @qrvey_response.find do |qrvey_dashboard_response|
        qrvey_dashboard_response.dashboard_id == @current_dashboard_id
      end
    end

    def current_dashboard_group_name
      if using_hardcoded_defaults? || current_dashboard.built_in_dashboard?
        "Results"
      elsif current_dashboard.dashboard_owned_by_user?(@current_user_id)
        "My Reports"
      elsif current_dashboard.dashboard_shared_with_user?(@current_user_id)
        "Shared With Me"
      else
        ""
      end
    end

    def current_dashboard_name
      if using_hardcoded_defaults?
        QRVEY_CONFIG[:client_reports][:dashboards].find { |dashboard| dashboard[:id] == @current_dashboard_id }[:display_name]
      else
        current_dashboard.dashboard_name
      end
    end

    private

    def request_data_from_qrvey
      return nil unless @account.registered_with_qrvey?

      @qrvey_user = @account.qrvey_user
      @qrvey_application = @qrvey_user.qrvey_applications.first

      QrveyBridge.get_all_dashboards(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id)
    end

    def using_qrvey?
      @qrvey_response.present?
    end

    def shared_with_me_dashboard_links
      dashboard_links(shared_with_me_dashboard_info)
    end

    def my_dashboard_links
      dashboard_links(my_dashboard_info)
    end

    def built_in_dashboard_links
      links = []

      if @survey_id
        links << {
          text: "Overview",
          url: report_survey_path(@survey_id),
          current: @current_dashboard_id.nil?,
          dashboardId: nil
        }
      end

      links + dashboard_links(built_in_dashboard_info)
    end

    def dashboard_links(names_and_ids)
      names_and_ids.map do |dashboard_name, dashboard_id|
        link = {
          text: dashboard_name,
          url: client_reports_qrvey_path(survey_id: @survey_id, dashboard_id: dashboard_id),
          current: @current_dashboard_id == dashboard_id,
          dashboardId: dashboard_id,
          additionalClasses: 'sublist-item'
        }

        if authorization.dig(dashboard_id, :canEdit)
          link[:editModeUrl] = client_reports_qrvey_path(survey_id: @survey_id, dashboard_id: dashboard_id, mode: "edit")
        end

        link
      end
    end

    def hardcoded_defaults
      QRVEY_CONFIG[:client_reports][:dashboards].map do |dashboard|
        [dashboard[:display_name], dashboard[:id]]
      end
    end

    def my_dashboard_info
      return [] unless using_qrvey?

      dashboards = @qrvey_response.select do |qrvey_dashboard_response|
        qrvey_dashboard_response.dashboard_owned_by_user?(@current_user_id)
      end

      dashboards.sort_by(&:dashboard_name).map do |qrvey_dashboard_response|
        [qrvey_dashboard_response.dashboard_name, qrvey_dashboard_response.dashboard_id]
      end
    end

    def shared_with_me_dashboard_info
      return [] unless using_qrvey?

      dashboards = @qrvey_response.select do |qrvey_dashboard_response|
        qrvey_dashboard_response.dashboard_shared_with_user?(@current_user_id)
      end

      dashboards.sort_by(&:dashboard_name).map do |qrvey_dashboard_response|
        [qrvey_dashboard_response.dashboard_name, qrvey_dashboard_response.dashboard_id]
      end
    end

    def built_in_dashboard_info
      return hardcoded_defaults unless using_qrvey?

      expected_dashboards = QrveyDashboardMapping.all.order(:position)
      missing_dashboard_names = []

      dashboard_names_and_ids = expected_dashboards.map do |dashboard|
        qrvey_dashboard = @qrvey_response.detect do |qrvey_dashboard_response|
          qrvey_dashboard_response.dashboard_name == dashboard.qrvey_name
        end

        if qrvey_dashboard
          qrvey_dashboard_id = qrvey_dashboard.dashboard_id

          [dashboard.pi_name, qrvey_dashboard_id]
        else
          missing_dashboard_names << dashboard.qrvey_name

          nil
        end
      end.compact

      return hardcoded_defaults if missing_dashboard_names == expected_dashboards.map(&:qrvey_name)

      missing_dashboard_names.each do |missing_dashboard_name|
        Rollbar.warning(
          "Could not find Qrvey dashboard",
          dashboard_name: missing_dashboard_name,
          pi_qrvey_user_id: @qrvey_user.id,
          pi_qrvey_application_id: @qrvey_application.id
        )
      end

      dashboard_names_and_ids
    end
  end
end
