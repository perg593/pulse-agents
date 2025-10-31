# frozen_string_literal: true

module Numerable
  extend ActiveSupport::Concern

  include ActiveSupport::NumberHelper

  def percent_of(dividend, divisor, precision: 0)
    return "0%" if divisor.zero?

    number_to_percentage(dividend * 100 / divisor.to_f, precision: precision)
  end
end
