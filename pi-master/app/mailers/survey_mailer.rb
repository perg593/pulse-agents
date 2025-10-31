# frozen_string_literal: true
class SurveyMailer < ActionMailer::Base
  default from: 'Pulse Insights Notifications <notifications@pulseinsights.com>'
  default bcc: 'ops@pulseinsights.com'

  def send_completion_email(survey_id)
    @survey = Survey.find(survey_id)
    @email = @survey.account.email

    mail(to: @email, subject: "#{@survey.account.name} Survey [#{@survey.name}] has reached its goal.")
  end

  def survey_reached_end_date_email(survey_id)
    @survey = Survey.find(survey_id)
    recipient = @survey.account.email

    mail(to: recipient, subject: "#{@survey.account.name} Survey [#{@survey.name}] has reached its end date.")
  end
end
