# frozen_string_literal: true

class ReportJobPresenter
  include Rails.application.routes.url_helpers

  def initialize(user, survey: nil, survey_locale_group: nil)
    @user = user
    @survey = survey
    @survey_locale_group = survey_locale_group
  end

  def export_job(report_job)
    result = {
      "id" => report_job.id,
      "status" => report_job.status.to_s,
      "downloadUrl" => report_job.report_url,
      "emailAddress" => report_job.current_user_email
    }

    if @user.admin?
      result["createdAt"] = report_job.created_at.to_i * 1000
      result["updatedAt"] = report_job.updated_at.to_i * 1000
    end

    result
  end

  def export_jobs
    max_to_show = 5

    report_jobs = ReportJob.where(user: @user, survey: @survey, survey_locale_group: @survey_locale_group).
                  where("updated_at > ?", 7.days.ago).
                  order(created_at: :desc).
                  limit(max_to_show)

    report_jobs.map { |report_job| export_job(report_job) }
  end

  def report_creation_path
    if @survey
      report_jobs_path(survey_id: @survey.id)
    elsif @survey_locale_group
      report_jobs_path(survey_locale_group_id: @survey_locale_group.id)
    end
  end
end
