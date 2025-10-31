# frozen_string_literal: true

module AuthControllerConcern
  extend ActiveSupport::Concern

  included do
    layout 'auth'
    before_action :require_logout!
  end
end
