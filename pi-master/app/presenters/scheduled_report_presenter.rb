# frozen_string_literal: true
class ScheduledReportPresenter
  include Rails.application.routes.url_helpers

  def initialize(current_account, scheduled_report)
    @account = current_account
    @scheduled_report = scheduled_report
  end

  def form_attributes
    edit_page = @scheduled_report.persisted?

    {
      dateRangeOptions: date_range_options,
      emailOptions: email_options,
      frequencyOptions: frequency_options,
      surveyLocaleGroupOptions: survey_locale_group_options,
      surveyOptions: survey_options,
      name: @scheduled_report.name,
      frequency: @scheduled_report.frequency.to_s,
      dataRange: @scheduled_report.date_range.to_s,
      startDate: @scheduled_report.start_date.to_i * 1000,
      endDate: @scheduled_report.end_date.to_i * 1000,
      formUrl: edit_page ? scheduled_report_path(@scheduled_report.id) : scheduled_reports_path,
      formMethod: edit_page ? "PATCH" : "POST",
      allSurveys: @scheduled_report.all_surveys,
      sendNoResultsEmail: @scheduled_report.send_no_results_email
    }
  end

  def date_range_options
    options = {
      one_month: "Previous Month",
      one_week: "Previous Week",
      one_day: "Previous Day",
      year_to_date: "Year to date",
      all_time: "All Time"
    }

    options.map { |value, label| {label: label, value: value} }
  end

  def email_options
    scheduled_report_emails.map do |scheduled_report_email|
      email_address = scheduled_report_email.email

      {
        id: scheduled_report_email.id,
        label: email_address,
        email: email_address,
        checked: scheduled_report_email.persisted?
      }
    end
  end

  def frequency_options
    ScheduledReport.frequencies.map { |label, _value| {label: label.titleize, value: label} }
  end

  def survey_options
    @account.surveys.where(survey_locale_group_id: nil).order(:name).map do |survey|
      individual_survey_option(survey)
    end
  end

  def survey_locale_group_options
    @account.survey_locale_groups.order(:name).map do |survey_locale_group|
      surveys = survey_locale_group.surveys.order(:name).map { |survey| individual_survey_option(survey) }

      if @scheduled_report
        scheduled_report_survey_locale_group = @scheduled_report.scheduled_report_survey_locale_groups.find_by(locale_group_id: survey_locale_group.id)
      end

      {
        id: scheduled_report_survey_locale_group&.id,
        surveyLocaleGroupId: survey_locale_group.id,
        label: survey_locale_group.name,
        initiallyChecked: scheduled_report_survey_locale_group.present?,
        surveys: surveys
      }
    end
  end

  private

  def individual_survey_option(survey)
    if @scheduled_report
      scheduled_report_survey = @scheduled_report.scheduled_report_surveys.find_by(survey_id: survey.id)

      @scheduled_report.scheduled_report_survey_locale_groups.each do |scheduled_report_survey_locale_group|
        scheduled_report_survey ||= scheduled_report_survey_locale_group.scheduled_report_surveys.find_by(survey_id: survey.id)
      end
    end

    {
      scheduledReportSurveyId: scheduled_report_survey&.id,
      surveyId: survey.id,
      label: survey.name,
      initiallyChecked: scheduled_report_survey.present?
    }
  end

  def scheduled_report_emails
    registered_emails = @scheduled_report ? @scheduled_report.scheduled_report_emails.pluck(:email) : []
    email_addresses = (registered_emails + @account.users.pluck(:email)).uniq.sort

    email_addresses.map do |email|
      ScheduledReportEmail.find_or_initialize_by(scheduled_report: @scheduled_report, email: email)
    end
  end
end
