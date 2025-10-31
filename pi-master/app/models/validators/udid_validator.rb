# frozen_string_literal: true

class UdidValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?
    record.errors.add attribute, "Invalid UDID: #{value}" unless valid_udid?(value)
  end

  def valid_udid?(udid)
    # TODO: upgrate the Ruby version to 2.5 https://www.ruby-lang.org/en/news/2019/03/31/support-of-ruby-2-3-has-ended/
    # udid.match?(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
    !!(udid =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
  end
end
