# frozen_string_literal: true
class EmailValidator < ActiveModel::EachValidator
  REGEXP = /^(|(([A-Za-z0-9]+_+)|([A-Za-z0-9]+-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Za-z0-9]+@((\w+-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6})$/i
  def validate_each(record, _attribute, value)
    record.errors.add(:email, "is not an e-mail address") unless
      value =~ REGEXP
  end
end
