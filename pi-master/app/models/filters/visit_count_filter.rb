# frozen_string_literal: true

module Filters
  class VisitCountFilter < ComparatorFilter
    def to_sql
      "submissions.visit_count #{comparator_sql(@comparator)} #{@value}"
    end
  end
end
