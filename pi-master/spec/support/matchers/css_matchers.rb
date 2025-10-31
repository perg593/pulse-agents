# frozen_string_literal: true
require 'rspec/expectations'

module CssMatchers
  RSpec::Matchers.define :have_class do |class_name|
    match do |element|
      classes = element.attribute("class").split

      classes.include?(class_name)
    end

    failure_message do |actual|
      "Expected #{actual.attribute("class")} to include #{expected}"
    end
  end
end
