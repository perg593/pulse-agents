# frozen_string_literal: true
require 'spec_helper'

describe Retryable do
  describe "retryable" do
    it 'is retryable as many times as max_retry_count' do
      max_retry_count = 5
      count = 0
      described_class.with_retry(max_retry_count: max_retry_count) do
        count += 1
        raise if count < max_retry_count + 1 # +1 is for the original run
      end
      expect(count).to eq max_retry_count + 1
    end

    it "raises an error after hitting the max retry count" do
      count = 0
      expect { described_class.with_retry { count += 1 and raise } }.to raise_error RuntimeError
      expect(count).to eq described_class::DEFAULT_MAX_RETRY_COUNT + 1 # +1 is for the original run
    end

    it 'sets an interval between attempts' do
      interval = 1 # seconds
      start_time = Time.current

      count = 0
      described_class.with_retry(interval: interval) do
        count += 1
        raise if count < described_class::DEFAULT_MAX_RETRY_COUNT + 1 # +1 is for the original run
      end

      end_time = Time.current
      expect(end_time - start_time).to be >= interval * described_class::DEFAULT_MAX_RETRY_COUNT
    end
  end
end
