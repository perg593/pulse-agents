# frozen_string_literal: true
module Auth
  module RegistrationsHelper
    def sign_in_page?
      controller_name == 'sessions' && %w(new saml_signin).include?(action_name)
    end
  end
end
