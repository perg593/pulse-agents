# frozen_string_literal: true
module Admin
  class QrveyUsersController < BaseController
    require_relative "../../../lib/qrvey_client/qrvey_client"

    include Control::RedirectHelper

    before_action :set_account
    before_action :set_qrvey_user
    before_action :set_qrvey_application

    def show
      @dashboards = QrveyBridge.get_all_dashboards(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id)
    end

    def delete_dashboard
      qrvey_user_id = @qrvey_user.qrvey_user_id
      qrvey_application_id = @qrvey_application.qrvey_application_id
      qrvey_dashboard_id = params[:qrvey_dashboard_id]

      QrveyClient.delete_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_id)

      flash.notice = "Deleted dashboard!"
    rescue QrveyClient::HTTP::QrveyError => e
      flash.notice = "Failed to deleted dashboard! #{e.message}"
    ensure
      redirect_to admin_account_qrvey_user_path(@account)
    end

    private

    def set_account
      @account = Account.find_by(id: params[:account_id])

      handle_missing_record unless @account
    end

    def set_qrvey_user
      @qrvey_user = @account.qrvey_user
    end

    def set_qrvey_application
      @qrvey_application = @qrvey_user.qrvey_applications.find_by(id: params[:qrvey_application_id]) || @qrvey_user.qrvey_applications.first
    end
  end
end
