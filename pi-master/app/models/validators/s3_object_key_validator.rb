# frozen_string_literal: true

# Validates that a string is acceptable to be used as an S3 object key
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
class S3ObjectKeyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    characters_to_avoid = [
      "\\", "{", "^", "}", "%", "`", "]", "\"", ">", "[", "~", "<", "#", "|",
      "&", "$", "@", "=", ";", ":", "+", " ", ",", "?"
    ]

    return unless characters_to_avoid.any? { |character| value.include?(character) }

    record.errors.add attribute, "Invalid S3 Object Key: #{value}. S3 doesn't like these characters: #{characters_to_avoid.join(',')}"
  end
end
