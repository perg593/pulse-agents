# frozen_string_literal: true

module Filters
  class PageviewCountFilter < ComparatorFilter
    def to_sql
      "submissions.pageview_count #{comparator_sql(@comparator)} #{@value}"
    end
  end
end
