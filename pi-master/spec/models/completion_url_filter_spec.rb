# frozen_string_literal: true
require 'spec_helper'

describe CompletionUrlFilter do
  let(:value) { "test.site.com" }

  describe "constructor" do
    it "returns a CompletionUrlFilter object" do
      matcher = "contains"
      cumulative = true

      filter = described_class.new(matcher, value, cumulative: cumulative)
      expect(filter.matcher).to eq(matcher)
      expect(filter.value).to eq(value)
      expect(filter.cumulative).to eq(cumulative)
    end

    it "fails if matcher is not an accepted value" do
      cumulative = true

      assert_raises(ArgumentError) { described_class.new('foo', value, cumulative: cumulative) }
    end
  end

  describe "SQL injection" do
    it "is not vulnerable to SQL injection" do
      mean_values = ["%') UNION select email from users --;", "') UNION select email from users --;"]
      matchers = described_class::VALID_COMPLETION_URL_MATCHERS

      submission = create(:submission, url: FFaker::Lorem.word, survey: create(:survey))

      email = FFaker::Internet.email
      user = create(:user, email: email)

      mean_values.product(matchers).each do |mean_value, matcher|
        filter = described_class.new(matcher, mean_value, cumulative: true)

        urls = begin
          Submission.select("url").where(filter.to_sql).pluck(:url)
        rescue
          # An exception in query execution means the SQL injection attempt failed
          []
        end

        expect(urls.include?(email)).to be false
      end
    end
  end

  describe "to_sql" do
    let(:cumulative) { true }

    it "returns an sql string representing 'contains'" do
      matcher = "contains"

      filter = described_class.new(matcher, value, cumulative: cumulative)
      expect(filter.to_sql).to eq("submissions.url LIKE '%#{value}%'")
    end

    it "returns an sql string representing 'does not contain'" do
      matcher = "does_not_contain"

      filter = described_class.new(matcher, value, cumulative: cumulative)
      expect(filter.to_sql).to eq("submissions.url NOT LIKE '%#{value}%'")
    end

    it "returns an sql string representing a regular expression" do
      matcher = "regex"

      filter = described_class.new(matcher, value, cumulative: cumulative)
      expect(filter.to_sql).to eq("submissions.url ~* '#{value}'")
    end
  end

  describe "combined_filters" do
    it "returns an SQL string built from a combination of multiple filters" do
      non_cumulative_filters = 2.times.map { |_| described_class.new("contains", FFaker::Lorem.word, cumulative: false) }
      cumulative_filters = 2.times.map { |_| described_class.new("contains", FFaker::Lorem.word, cumulative: true) }

      2.times do |i|
        cur_cumulative_filters = cumulative_filters.first(i)

        2.times do |j|
          cur_non_cumulative_filters = non_cumulative_filters.first(j)

          cumulative_join_strings = cur_cumulative_filters.map(&:to_sql)
          non_cumulative_join_strings = cur_non_cumulative_filters.map(&:to_sql)

          submission_join_string = []
          submission_join_string << " (#{cumulative_join_strings.join(" AND ")}) " if cumulative_join_strings.present?
          submission_join_string << " (#{non_cumulative_join_strings.join(" OR ")}) " if non_cumulative_join_strings.present?
          submission_join_string = submission_join_string.join(" AND ")

          expect(described_class.combined_sql(cur_cumulative_filters + cur_non_cumulative_filters)).to eq(submission_join_string)
        end
      end
    end
  end
end
