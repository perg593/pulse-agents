# frozen_string_literal: true

module Filters
  class ComparatorFilter < Filter
    attr_accessor :comparator, :value

    VALID_COMPARATORS = [
      COMPARATOR_LESS_THAN,
      COMPARATOR_LESS_THAN_OR_EQUAL_TO,
      COMPARATOR_EQUAL_TO,
      COMPARATOR_GREATER_THAN_OR_EQUAL_TO,
      COMPARATOR_GREATER_THAN
    ].freeze

    def initialize(comparator, value)
      @comparator = comparator
      @value = value

      raise ArgumentError, "Invalid comparator #{@comparator}" unless VALID_COMPARATORS.include? @comparator
      raise ArgumentError, "Invalid value #{@value}" unless @value.instance_of?(Integer) && @value >= 0

      super()
    end

    def ==(other)
      other.respond_to?(:comparator) &&
        other.respond_to?(:value) &&
        other.comparator == @comparator &&
        other.value == @value
    end

    def comparator_sql(comparator)
      case comparator
      when COMPARATOR_LESS_THAN
        "<"
      when COMPARATOR_LESS_THAN_OR_EQUAL_TO
        "<="
      when COMPARATOR_EQUAL_TO
        "="
      when COMPARATOR_GREATER_THAN_OR_EQUAL_TO
        ">="
      when COMPARATOR_GREATER_THAN
        ">"
      end
    end

    def self.from_params(params)
      hash = JSON.parse(params, symbolize_names: true)

      new(hash[:comparator]&.to_s, Integer(hash[:value]))
    rescue TypeError
      Rails.logger.info "Ignoring invalid filter, Not a JSON string: #{params}"
      nil
    rescue JSON::ParserError
      Rails.logger.info "Ignoring invalid filter, Invalid JSON: #{params}"
      nil
    rescue ArgumentError
      Rails.logger.info "Ignoring invalid filter, #{params}"
      nil
    end
  end
end
