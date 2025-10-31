# frozen_string_literal: true
module Control
  class ScheduledReportsController < BaseController
    before_action :set_scheduled_report, only: %i(edit destroy update pause restart)

    def index
      @reports = current_account.scheduled_reports.left_joins(:scheduled_report_emails, :surveys, :survey_locale_groups).group(:id).select(<<-SQL)
      	scheduled_reports.*,
	      array_agg(distinct(scheduled_report_emails.email)) emails,
	      array_agg(distinct(jsonb_build_object('id', locale_groups.id, 'name', locale_groups.name))) survey_locale_groups,
	      array_agg(distinct(jsonb_build_object('id', surveys.id, 'name', surveys.name))) surveys
      SQL
      @audits = current_user.account.associated_audits.for_index(controller_name.classify) if current_user.admin?
    end

    def new
      @report = ScheduledReport.new
      @presenter = ScheduledReportPresenter.new(current_account, @report)
    end

    def edit
      @audits = @report.own_and_associated_audits.descending if current_user.admin?
      @presenter = ScheduledReportPresenter.new(current_account, @report)
    end

    def update
      result = @report.update(scheduled_report_params)

      if result
        redirect_to scheduled_reports_path, notice: 'Scheduled Report was successfully updated.'
      else
        redirect_to edit_scheduled_report_path(@report.id), alert: @report.errors.full_messages.join(", ")
      end
    end

    def destroy
      @report.destroy
      redirect_to scheduled_reports_path, notice: 'Scheduled Report was successfully destroyed.'
    end

    def create
      @report = ScheduledReport.new(scheduled_report_params)
      @report.account_id = current_user.account.id

      if @report.save
        redirect_to scheduled_reports_path, notice: 'Scheduled Report was successfully created.'
      else
        flash.now.alert = @report.errors.full_messages.join(', ')
        @presenter = ScheduledReportPresenter.new(current_account, @report)
        render :new
      end
    end

    def restart
      @report.update paused: false, send_next_report_at: Time.current.beginning_of_minute + 2.minutes
      redirect_to scheduled_reports_path, notice: 'Scheduled Report was successfully restarted.'
    end

    def pause
      @report.update paused: true
      redirect_to scheduled_reports_path, notice: 'Scheduled Report was successfully paused.'
    end

    private

    def set_scheduled_report
      @report = current_account.scheduled_reports.find_by(id: params[:id])

      redirect_to dashboard_path and return unless @report
    end

    def scheduled_report_params
      params_data = params.require(:scheduled_report).permit(
        :name, :frequency, :start_date, :end_date, :send_report_hour, :date_range, :all_surveys, :send_no_results_email,
        {
          scheduled_report_survey_locale_groups_attributes: [
            :id, :_destroy, :locale_group_id,
            {
              scheduled_report_surveys_attributes: [:id, :_destroy, :survey_id]
            }
          ]
        },
        {
          scheduled_report_surveys_attributes: [:id, :_destroy, :survey_id]
        },
        scheduled_report_emails_attributes: [:id, :_destroy, :email]
      )

      scheduled_report_dates_params(params_data, params_data[:start_date], params_data[:end_date])
    end

    def scheduled_report_dates_params(params_data, start_date, end_date)
      params_data[:start_date] = Time.zone.parse(start_date) if start_date.present?
      params_data[:end_date] = Time.zone.parse(end_date) if end_date.present?

      params_data
    end
  end
end
