# frozen_string_literal: true
module Admin
  module UsersHelper
    def infos_for_user(user)
      output = ""
      if user.company_name.present?
        output += truncate(user.company_name)
        output += "<br />"
      end
      output += sanitize(user.name)
      output += "(#{user.email})"
      output.html_safe
    end

    def user_time_zone
      cookies[:pi_console_timezone]
    end
  end
end
