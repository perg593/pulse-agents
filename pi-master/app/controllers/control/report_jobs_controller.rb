# frozen_string_literal: true

module Control
  class ReportJobsController < BaseController
    include FiltersHelper

    IMPRESSION_THRESHOLD = 3_000_000

    before_action :require_reportee, only: :create

    def create
      report_job = ReportJob.new(
        user: current_user,
        survey_id: params[:survey_id],
        survey_locale_group_id: params[:survey_locale_group_id],
        current_user_email: current_user.email,
        sudo_from_id: session[:sudo_from_id],
        filters: report_job_filters
      )

      render json: { error: "An identical report job is already queued or in progress." }, status: 409 and return if ReportJob.already_queued?(report_job)

      if !report_job.filters? && (report_job.survey || report_job.survey_locale_group)&.cached_impressions_count.to_i >= IMPRESSION_THRESHOLD
        render json: { error: "Too many results - please apply filters, or contact your Customer Success Manager for assistance." }, status: 404 and return
      end

      report_job.save

      render json: { error: "Failed to save report" }, status: 404 and return unless report_job.persisted?

      # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1981
      #   Waiting 1 sec to ensure that the ReportJob record is there before the job is processed.
      #   1 sec should be enough because the database replication lag hasn't reached 300ms for the
      #   last 6 months(2022/7/1 - 2023/1/1) even though a ReportJob record wasn't there when needed
      #   for several times in the meantime https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1981#note_1033515
      ReportWorker.perform_in(1.second, report_job.id)

      render json: { reportJob: ReportJobPresenter.new(current_user).export_job(report_job) }, status: :ok
    end

    def status
      report_job = ReportJob.find_by_id(params[:id])

      if user_queued_job?(report_job)
        render json: { status: report_job.status, url: report_job.report_url }, status: :ok
      else
        render json: {}, status: :forbidden
      end
    end

    private

    def user_queued_job?(report_job)
      if report_job.sudo_from_id
        return true if report_job.sudo_from_id == session[:sudo_from_id]
      elsif report_job.user_id == current_user.id
        return true
      end

      false
    end

    def report_job_filters
      filters = parse_filters(params)

      device_filter = filters[:device_types] # Same filter, different name

      filters = filters.slice(:date_range, :completion_urls, :pageview_count, :visit_count)
      filters[:device_filter] = device_filter

      filters.compact
    end

    def require_reportee
      if params[:survey_id]
        reportee = current_account.surveys.find_by_id(params[:survey_id])
      elsif params[:survey_locale_group_id]
        reportee = current_account.survey_locale_groups.find_by_id(params[:survey_locale_group_id])
      else
        render json: :forbidden, status: 404 and return
      end

      render json: { error: "Reportee Not Found" }, status: :forbidden and return unless reportee
    end
  end
end
