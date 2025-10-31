# frozen_string_literal: true
require 'rspec/core'

class DetailedFailureFormatter < RSpec::Core::Formatters::ProgressFormatter
  def initialize(output)
    super(output)

    @output = output
    @custom_info = {}
  end

  def add_info(info)
    @custom_info.merge!(info)
  end

  def example_failed(example)
    @output.puts "Failure in: #{example.full_description}"

    log_additional_info
  end

  private

  def log_additional_info
    @custom_info.each do |key, value|
      @output.puts "#{key}: #{value}"
    end
  end
end
