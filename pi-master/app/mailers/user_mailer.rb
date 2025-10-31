# frozen_string_literal: true
class UserMailer < ActionMailer::Base
  default bcc: 'ops@pulseinsights.com'

  layout "mailers/client_facing", except: [:locked_notification]

  def reset_email(current_email, new_email, reset_email_token)
    @current_email = current_email
    @new_email = new_email
    @reset_email_token = reset_email_token
    @email = @current_email
    mail(to: current_email, subject: '[Pulse Insights] Reset your email')
  end

  def send_out_invitation(invitation)
    @invitation = invitation
    @email = @invitation.email

    mail(to: @invitation.email, subject: 'You have been invited to Pulse Insights')
  end

  def locked_notification(user, ip)
    @email = user.email
    @ip = ip

    mail(to: 'alerts@pulseinsights.com',
         subject: "[Pulse Insights] 8 unsuccessful login attempts for #{@email}")
  end

  def automation_triggered(emails, survey_name, question_name, automation_names, answer)
    @survey_name = survey_name
    @question_name = question_name
    @automation_names = automation_names
    @answer = answer
    @email = emails.join(", ")

    mail(to: emails,
         subject: '[Pulse Insights] Automation triggered')
  end

  def suspicious_behaviour_detected(user, ip)
    @user = user
    @ip = ip

    mail(to: "dev.pulseinsights@ekohe.com",
         cc: "alerts@pulseinsights.com",
         subject: "Suspicious Behaviour Detected")
  end
end
