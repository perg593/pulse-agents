# frozen_string_literal: true
module Filters
  class Filter
    def to_sql
      raise NotImplementedError, "#{self.class} must implement to_sql"
    end

    def ==(other)
      raise NotImplementedError, "#{self.class} must implement =="
    end
  end
end
