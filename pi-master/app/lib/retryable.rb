# frozen_string_literal: true

module Retryable
  DEFAULT_MAX_RETRY_COUNT = 3 # times
  DEFAULT_REQUEST_INTERVAL = 0 # seconds

  # Run a given block until it becomes successful or it hits the max retry count. The latter will raise an error
  #   max_retry_count: number of retries before we consider it an error
  #   interval: time spent between requests in second
  def self.with_retry(max_retry_count: DEFAULT_MAX_RETRY_COUNT, interval: DEFAULT_REQUEST_INTERVAL, logger: Rails.logger)
    retry_count ||= 0
    yield
  rescue => e
    if retry_count >= max_retry_count
      logger.error "Hit the max retry count #{max_retry_count} due to #{e}"
      raise e
    else
      logger.info "Retrying(#{retry_count += 1})"
      sleep(interval)
      retry
    end
  end
end
