# frozen_string_literal: true
module Control
  class BaseController < ApplicationController
    layout 'control'
    before_action :require_user!
    before_action :set_legacy_behaviour

    private

    # rubocop:disable Naming/MemoizedInstanceVariableName
    # This error will go away when we next add a legacy behaviour setting
    def set_legacy_behaviour
      @legacy_behaviour ||= {}
    end
  end
end
