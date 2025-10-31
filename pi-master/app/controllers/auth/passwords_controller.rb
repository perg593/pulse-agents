# frozen_string_literal: true
module Auth
  class PasswordsController < Devise::PasswordsController
    include ApplicationControllerConcern
    include AuthControllerConcern

    def create
      super

      # Sleep 200 to 800 ms randomly to make up the time difference while requesting with non-existent users, so that
      # existent users can't be identified by comparing request times. https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2366
      sleep rand(0.2..0.8) unless resource.persisted? || Rails.env.test?
    end
  end
end
