# frozen_string_literal: true

module Devise
  class UserMailer < Devise::Mailer
    default bcc: 'ops@pulseinsights.com'

    layout "mailers/client_facing"

    def reset_password_instructions(record, token, _opts = {})
      @email = record.email
      @token = token

      mail(
        to: @email,
        cc: 'alerts@pulseinsights.com',
        subject: '[Pulse Insights] Reset your password',
        template_path: 'devise/mailer'
      )
    end
  end
end
