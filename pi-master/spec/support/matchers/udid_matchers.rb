# frozen_string_literal: true
require 'rspec/expectations'

module UdidMatchers
  UDID_REGEX = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i

  RSpec::Matchers.define :be_udid do
    match do |element|
      UDID_REGEX.match?(element)
    end

    failure_message do |actual|
      "Expected #{actual} to match #{UDID_REGEX}"
    end
  end
end
