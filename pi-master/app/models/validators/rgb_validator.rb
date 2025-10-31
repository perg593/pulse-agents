# frozen_string_literal: true

# Validates a color code is in the RGB format
class RgbValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if value.match?(/\A#([a-fA-F0-9]{3}|[a-fA-F0-9]{6})\z/)

    record.errors.add attribute, "Invalid RGB Code: #{value}"
  end
end
