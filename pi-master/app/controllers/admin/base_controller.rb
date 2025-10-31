# frozen_string_literal: true
module Admin
  class BaseController < ApplicationController
    layout 'control'
    before_action :require_admin!
  end
end
