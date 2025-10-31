# frozen_string_literal: true

class CompletionUrlFilter
  attr_accessor :matcher, :value, :cumulative

  VALID_COMPLETION_URL_MATCHERS = %w(contains does_not_contain regex).freeze

  def initialize(matcher, value, cumulative:)
    @matcher = matcher
    @value = value
    @cumulative = cumulative

    raise ArgumentError unless VALID_COMPLETION_URL_MATCHERS.include? matcher
  end

  def ==(other)
    other.respond_to?(:matcher) &&
      other.respond_to?(:value) &&
      other.respond_to?(:cumulative) &&
      other.matcher == @matcher &&
      other.value == @value &&
      other.cumulative == @cumulative
  end

  def to_sql
    case @matcher
    when "contains"
      ActiveRecord::Base.sanitize_sql_for_conditions(["submissions.url LIKE ?", "%#{@value}%"])
    when "does_not_contain"
      ActiveRecord::Base.sanitize_sql_for_conditions(["submissions.url NOT LIKE ?", "%#{@value}%"])
    when "regex"
      ActiveRecord::Base.sanitize_sql_for_conditions(["submissions.url ~* ?", @value])
    end
  end

  def self.combined_sql(filters)
    cumulative_join_strings, non_cumulative_join_strings = filters.partition(&:cumulative)

    cumulative_join_strings = cumulative_join_strings.map(&:to_sql)
    non_cumulative_join_strings = non_cumulative_join_strings.map(&:to_sql)

    submission_join_string = []
    submission_join_string << " (#{cumulative_join_strings.join(" AND ")}) " if cumulative_join_strings.present?
    submission_join_string << " (#{non_cumulative_join_strings.join(" OR ")}) " if non_cumulative_join_strings.present?
    submission_join_string.join(" AND ")
  end
end
