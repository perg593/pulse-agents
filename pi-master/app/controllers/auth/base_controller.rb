# frozen_string_literal: true
module Auth
  class BaseController < ApplicationController
    layout 'auth'
    before_action :require_logout!
  end
end
