# frozen_string_literal: true
module Control
  class QrveyController < BaseController
    include RedirectHelper

    require_relative "../../../lib/qrvey_client/qrvey_client"

    before_action :require_qrvey_enabled
    before_action :require_admin!, only: :platform_health
    before_action :set_survey, only: :client_reports
    before_action :require_qrvey_registration, only: %i(change_dashboard_permissions share_dashboard clone_dashboard create_dashboard delete_dashboard)

    before_action :set_qrvey_user, only: %i(change_dashboard_permissions share_dashboard clone_dashboard create_dashboard delete_dashboard)
    before_action :set_qrvey_application, only: %i(change_dashboard_permissions share_dashboard clone_dashboard create_dashboard delete_dashboard)
    before_action :set_dashboard, only: %i(change_dashboard_permissions share_dashboard delete_dashboard)

    def change_dashboard_permissions
      update_access_levels
    end

    def share_dashboard
      update_access_levels
    end

    def clone_dashboard
      cloned_dashboard = QrveyBridge.clone_dashboard(
        @qrvey_user.qrvey_user_id,
        @qrvey_application.qrvey_application_id,
        params[:qrvey_dashboard_id],
        params[:qrvey_dashboard_name]
      )
      cloned_dashboard_id = cloned_dashboard.dashboard_id

      custom_attributes = QrveyBridge::CustomAttributes.new
      custom_attributes.owner_id = current_user.id

      QrveyBridge.update_custom_attributes(
        @qrvey_user.qrvey_user_id,
        @qrvey_application.qrvey_application_id,
        cloned_dashboard_id,
        custom_attributes
      )

      redirect_to client_reports_qrvey_path(survey_id: params[:survey_id], dashboard_id: cloned_dashboard_id, mode: "edit")
    end

    def create_dashboard
      required_params = %i(dashboard_name dashboard_description)
      redirect_to dashboard_path and return unless required_params.all? { |required_param| params[required_param].present? }

      custom_attributes = QrveyBridge::CustomAttributes.new
      custom_attributes.owner_id = current_user.id

      qrvey_dashboard_response = QrveyBridge.create_dashboard(
        @qrvey_user.qrvey_user_id,
        @qrvey_application.qrvey_application_id,
        params[:dashboard_name],
        params[:dashboard_description],
        custom_attributes
      )
      new_dashboard_id = qrvey_dashboard_response.dashboard_id

      redirect_to client_reports_qrvey_path(survey_id: params[:survey_id], dashboard_id: new_dashboard_id, mode: "edit")
    end

    def delete_dashboard
      render json: {}, status: :forbidden and return unless @dashboard.can_delete?(current_user.id)

      QrveyClient.delete_dashboard(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id, params[:qrvey_dashboard_id])

      render json: {}, status: :ok
    rescue QrveyClient::HTTP::QrveyError => e
      flash.notice = "Failed to deleted dashboard! #{e.message}"

      render json: {}, status: 500
    end

    def default_account_level_dashboard_id
      return hardcoded_dashboard_ids.first unless current_user.account.registered_with_qrvey?

      dashboards = QrveyBridge.get_all_dashboards(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id)

      found_built_in = dashboards.any?(&:built_in_dashboard?)
      return hardcoded_dashboard_ids.first unless found_built_in

      QrveyDashboardMapping.all.order(:position).each do |qrvey_dashboard_mapping|
        matching_dashboard = dashboards.find { |dashboard| dashboard.dashboard_name == qrvey_dashboard_mapping.qrvey_name }

        return matching_dashboard.dashboard_id if matching_dashboard
      end
    end

    def client_reports
      if current_user.account.registered_with_qrvey?
        @qrvey_user = current_user.account.qrvey_user
        @qrvey_application = @qrvey_user.qrvey_applications.first
      end

      @dashboard_id = params[:dashboard_id]
      @dashboard_id ||= default_account_level_dashboard_id

      @datasets = if using_hardcoded_dashboard?
        QRVEY_CONFIG[:client_reports][:datasets]
      else
        QrveyDataset.fetch_datasets(@qrvey_user, @qrvey_application)
        @qrvey_application.reload.qrvey_datasets.map do |qrvey_dataset|
          {
            id: qrvey_dataset.qrvey_dataset_id,
            survey_id_column_id: qrvey_dataset.qrvey_survey_id_column_id
          }
        end
      end

      @qrvey_sidebar_presenter = QrveySidebarPresenter.new(@survey&.id, current_user.id, @dashboard_id)
      @can_edit = !using_hardcoded_dashboard? && @qrvey_sidebar_presenter.current_dashboard&.can_edit?(current_user.id)

      @qrvey_mode = params[:mode] if @can_edit
      @qrvey_mode ||= "view"
      @qv_token = generate_client_reports_token

      @render_breadcrumbs = @survey.present?
    end

    def dashboard_builder
      redirect_to dashboard_path and return unless current_user.account.id == 341 # IKEA

      @dashboard_id = QRVEY_CONFIG[:ikea_dashboard_id]
      @qv_token = generate_dashboard_builder_token
    end

    def platform_health
      @qv_token = generate_platform_health_token
    end

    private

    def hardcoded_dashboard_ids
      QRVEY_CONFIG[:client_reports][:dashboards].map { |dashboard| dashboard[:id] }
    end

    def using_hardcoded_dashboard?
      hardcoded_dashboard_ids.include?(@dashboard_id)
    end

    def require_qrvey_enabled
      return true if current_user.account.qrvey_enabled?

      redirect_to dashboard_path
      false
    end

    def require_qrvey_registration
      return true if current_user.account.registered_with_qrvey?

      redirect_to dashboard_path
      false
    end

    def set_survey
      @survey = current_account&.surveys&.find_by(id: params[:survey_id])
    end

    def set_qrvey_user
      @qrvey_user = current_user.account.qrvey_user
    end

    def set_qrvey_application
      @qrvey_application = @qrvey_user.qrvey_applications.first
    end

    def set_dashboard
      @dashboard = QrveyBridge.get_dashboard(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id, params[:qrvey_dashboard_id])
    end

    def generate_client_reports_token
      if using_hardcoded_dashboard?
        qrvey_user_id = QRVEY_CONFIG[:client_reports][:user_id]
        qrvey_application_id = QRVEY_CONFIG[:client_reports][:app_id]
      else
        qrvey_user_id = @qrvey_user.qrvey_user_id
        qrvey_application_id = @qrvey_application.qrvey_application_id
      end

      body = {
        userid: qrvey_user_id,
        appid: qrvey_application_id,
        permissions: [
          {
            dataset_id: @datasets.map { |dataset| dataset[:id] },
            record_permissions: [
              {
                security_name: "account_id",
                values: [current_user.account.id]
              }
            ]
          }
        ]
      }

      QrveyClient.generate_token(body)
    end

    def generate_dashboard_builder_token
      body = {
        userid: QRVEY_CONFIG[:dashboard_builder][:user_id],
        appid: QRVEY_CONFIG[:dashboard_builder][:app_id],
        dashboard_id: @dashboard_id,

        asset_permissions: {
          datasets: {
            dataset_ids: [QRVEY_CONFIG[:ikea_dataset_id]]
          }
        }
      }

      QrveyClient.generate_token(body)
    end

    def generate_platform_health_token
      body = {
        userid: QRVEY_CONFIG[:platform_health][:user_id],
        appid: QRVEY_CONFIG[:platform_health][:app_id],
        permissions: [
          {
            dataset_id: "*",
            record_permissions: [
              {
                security_name: "account_id",
                values: ['*'] # Allows access to all account data. Use with care
              }
            ]
          }
        ]
      }

      QrveyClient.generate_token(body)
    end

    def access_level_by_user_id
      @access_level_by_user_id ||= if params[:users].present?
        params[:users].each_with_object({}) do |user_param, result|
          user_id = user_param[:id]
          permissions = Integer(user_param[:permissions], exception: false)

          result[user_id] = permissions
          result
        end
      elsif params[:user_ids_to_share_with].present? && params[:permissions].present?
        permissions = Integer(params[:permissions], exception: false)

        params[:user_ids_to_share_with].each_with_object({}) do |user_id, result|
          result[user_id] = permissions
          result
        end
      else
        {}
      end
    end

    def update_access_levels
      custom_attributes = @dashboard.custom_attributes

      changes_authorized = access_level_by_user_id.all? do |user_id, access_level|
        AccountUser.where(user_id: user_id, account_id: current_user.account.id).exists? &&
          custom_attributes.access_level_change_allowed?(current_user.id, user_id, access_level)
      end
      redirect_back_or_to(dashboard_path) and return unless changes_authorized

      access_level_by_user_id.each do |user_id, access_level|
        if access_level.nil?
          custom_attributes.revoke_access(user_id)
        else
          custom_attributes.share_with(user_id, access_level)
        end
      end

      QrveyBridge.update_custom_attributes(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id, params[:qrvey_dashboard_id], custom_attributes)

      redirect_back_or_to(dashboard_path)
    end
  end
end
