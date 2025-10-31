# frozen_string_literal: true

class JsonValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    JSON.parse(value) if value.is_a?(String)
  rescue JSON::ParserError
    record.errors.add attribute, "Invalid JSON: #{value}"
  end
end
