# frozen_string_literal: true
class SurveyPreview < ActionMailer::Preview
  def send_completion_email
    SurveyMailer.send_completion_email(Survey.first.id)
  end

  def survey_reached_end_date_email
    SurveyMailer.survey_reached_end_date_email(Survey.first.id)
  end
end
