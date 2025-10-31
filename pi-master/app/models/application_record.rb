# frozen_string_literal: true
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # A record might not be created on time for 2 reasons:
  #   - PostgreSQL replication lag
  #   - Varying Sidekiq queue latency among servers
  FETCHING_INTERVAL = 5 # seconds

  def self.find_with_retry_by!(attribute)
    ActiveRecord::Base.uncached do # Otherwise the result would be the same across all attempts
      Retryable.with_retry(interval: FETCHING_INTERVAL) do
        find_by! attribute
      end
    end
  end
end
