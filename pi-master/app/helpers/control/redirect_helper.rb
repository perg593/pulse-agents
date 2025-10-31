# frozen_string_literal: true
module Control
  module RedirectHelper
    def handle_missing_record
      if request.xhr?
        render json: :forbidden, status: 404 # TODO: forbidden is 403
      else
        redirect_to dashboard_url
      end
    end
  end
end
