# frozen_string_literal: true
require 'spec_helper'
include Control::FiltersHelper

# TODO: Error (warning?) on unrecognized filter
# TODO: Error (warning?) on invalid device_type
# TODO: If the filters cover everything, maybe just discard them
describe Control::FiltersHelper do
  let(:invalid_survey_ids) { [nil, 'a', -7] }
  let(:valid_survey_ids) { [42, 43] }
  let(:valid_survey_id) { valid_survey_ids.first }

  let(:invalid_possible_answer_ids) { [nil, 'a', -7] }
  let(:valid_possible_answer_id) { 42 }

  let(:valid_device_types) { %w(email native_mobile desktop mobile tablet) }
  let(:invalid_device_types) { %w(filters hoge) }

  let(:valid_completion_url_matchers) { %w(contains does_not_contain regex) }
  let(:invalid_completion_url_matchers) { %w(resembles reminds_me_of) }

  let(:valid_pageview_count_comparators) { Filters::PageviewCountFilter::VALID_COMPARATORS }
  let(:invalid_pageview_count_comparators) { %w(resembles reminds_me_of) }

  let(:valid_visit_count_comparators) { Filters::VisitCountFilter::VALID_COMPARATORS }
  let(:invalid_visit_count_comparators) { %w(resembles reminds_me_of) }

  it "handles nil" do
    expect(parse_filters(nil)).to eq({})
  end

  it "discards unrecognized filters" do
    filter_params = { filters: %w(desktop) }

    expect(parse_filters(filter_params)).to eq({})
  end

  it "discards unrecognized device types" do
    filter_params = { device_types: valid_device_types + invalid_device_types }

    expect(parse_filters(filter_params)[:device_types]).to match_array(valid_device_types)
  end

  it "returns an empty hash when all device types are discarded" do
    filter_params = { device_types: invalid_device_types }

    expect(parse_filters(filter_params)).to eq({})
  end

  it "parses a single device filter" do
    filter_params = { device_types: valid_device_types.first }

    expect(parse_filters(filter_params)).to eq({ device_types: [valid_device_types.first] })
  end

  it "parses multiple device filters" do
    filter_params = { device_types: valid_device_types.first(2) }

    expect(parse_filters(filter_params)[:device_types]).to match_array(valid_device_types.first(2))
  end

  describe "date range filters" do
    let(:start_string) { "2021-01-13 00:00:00" }
    let(:end_string) { "2021-01-13 23:59:59" }

    let(:user_time_zone) { ActiveSupport::TimeZone["Pacific Time (US & Canada)"] }
    let(:filtering_time_zone) { ActiveSupport::TimeZone["GMT"] }

    let(:start_date) { user_time_zone.parse(start_string) }
    let(:end_date) { user_time_zone.parse(end_string) }

    let(:expected_start_date) { filtering_time_zone.parse(start_string) }
    let(:expected_end_date) { filtering_time_zone.parse(end_string) }

    def it_returns_a_valid_filter(filter_params)
      expect(parse_filters(filter_params)).to eq(
        { date_range: (expected_start_date..expected_end_date) }
      )
    end

    it "parses a legacy date_range filter" do
      filter_params = { from: start_date.to_s, to: end_date.to_s }
      it_returns_a_valid_filter(filter_params)
    end

    it "parses a date_range filter" do
      filter_params = { date_range: (start_date..end_date) }
      it_returns_a_valid_filter(filter_params)
    end

    it "parses a string date_range filter" do
      filter_params = { date_range: (start_date..end_date).to_s }
      it_returns_a_valid_filter(filter_params)
    end

    it "discards invalid date_ranges" do
      [[Time.current], ["garbage"], (1..100), ('a'..'z')].each do |invalid_date_range|
        filter_params = { date_range: invalid_date_range }
        expect(parse_filters(filter_params)).to eq({}), invalid_date_range.inspect
      end
    end
  end

  it "parses a possible_answer_id filter" do
    filter_params = { possible_answer_id: valid_possible_answer_id }

    expect(parse_filters(filter_params)).to eq({ possible_answer_id: valid_possible_answer_id })
  end

  it "discards invalid possible_answer_ids" do
    invalid_possible_answer_ids.each do |possible_answer_id|
      filter_params = { possible_answer_id: possible_answer_id }

      expect(parse_filters(filter_params)).to eq({})
    end
  end

  it "parses a market (survey_id) filter" do
    filter_params = { market_ids: valid_survey_id }

    expect(parse_filters(filter_params)).to eq({ market_ids: [valid_survey_id] })
  end

  it "parses multiple market (survey_id) filters" do
    filter_params = { market_ids: valid_survey_ids }

    expect(parse_filters(filter_params)).to eq({ market_ids: valid_survey_ids })
  end

  it "discards invalid market (survey_id) filters" do
    filter_params = { market_ids: (invalid_survey_ids + [valid_survey_id]) }

    expect(parse_filters(filter_params)).to eq({ market_ids: [valid_survey_id] })
  end

  it "returns an empty hash when all markets are discarded" do
    filter_params = { market_ids: invalid_survey_ids }

    expect(parse_filters(filter_params)).to eq({})
  end

  describe "completion URL filters" do
    it "parses a completion URL filter" do
      valid_filter = { matcher: valid_completion_url_matchers.first, value: 'filters.com', cumulative: false }

      expected_filters = [CompletionUrlFilter.new(valid_filter[:matcher], valid_filter[:value], cumulative: valid_filter[:cumulative])]

      filter_params = { completion_urls: [valid_filter.to_json] }

      expect(parse_filters(filter_params)).to eq({ completion_urls: expected_filters })
    end

    it "allows multiple completion URL filters" do
      valid_filters = [
        { matcher: valid_completion_url_matchers.first, value: 'filters.com', cumulative: false },
        { matcher: valid_completion_url_matchers.last, value: 'filters.com', cumulative: false },
        { matcher: valid_completion_url_matchers.first, value: 'filters.com', cumulative: true }
      ]

      expected_filters = valid_filters.map do |valid_filter|
        CompletionUrlFilter.new(valid_filter[:matcher], valid_filter[:value], cumulative: valid_filter[:cumulative])
      end

      filter_params = { completion_urls: valid_filters.map(&:to_json) }

      expect(parse_filters(filter_params)).to eq({ completion_urls: expected_filters })
    end

    it "discards invalid completion URL filter matchers" do
      invalid_filters = [
        { matcher: invalid_completion_url_matchers.first, value: 'bar', cumulative: false },
        { matcher: valid_completion_url_matchers.first, value: 'bar', cumulative: 'a' },
        { matcher: valid_completion_url_matchers.first, value: 'bar', cumulative: nil },
        { matcher: valid_completion_url_matchers.first, value: 'bar' },
        { matcher: valid_completion_url_matchers.first, value: nil, cumulative: false },
        { matcher: valid_completion_url_matchers.first, value: '', cumulative: false },
        { matcher: valid_completion_url_matchers.first, cumulative: false },
        { matcher: '', value: 'bar', cumulative: false },
        { matcher: nil, value: 'bar', cumulative: false },
        { value: 'bar', cumulative: false }
      ]

      valid_filter = { matcher: valid_completion_url_matchers.first, value: 'bar', cumulative: false }

      expected_filters = CompletionUrlFilter.new(valid_filter[:matcher], valid_filter[:value], cumulative: valid_filter[:cumulative])

      filter_params = { completion_urls: (invalid_filters + [valid_filter]).map(&:to_json) }

      expect(parse_filters(filter_params)).to eq({ completion_urls: [expected_filters] })
    end
  end

  describe "pageview count" do
    it "parses a pageview_count filter" do
      valid_filter = { comparator: valid_pageview_count_comparators.first, value: 5 }

      expected_filter = Filters::PageviewCountFilter.new(valid_filter[:comparator], valid_filter[:value])

      filter_params = { pageview_count: valid_filter.to_json }

      expect(parse_filters(filter_params)).to eq({ pageview_count: expected_filter })
    end

    it "discards invalid pageview_count filter comparators" do
      [
        { comparator: invalid_pageview_count_comparators.first, value: 'bar' },
        { comparator: valid_pageview_count_comparators.first, value: 'bar' },
        { comparator: valid_pageview_count_comparators.first, value: nil },
        { comparator: valid_pageview_count_comparators.first, value: '' },
        { comparator: valid_pageview_count_comparators.first, value: -2 },
        { comparator: '', value: 'bar' },
        { comparator: nil, value: 'bar' },
        { value: 'bar' }
      ].each do |invalid_filter|
        filter_params = { pageview_count: invalid_filter.to_json }

        # rubocop:disable Style/RedundantInterpolation
        # We want a custom error message and we can't simply use the variable
        expect(parse_filters(filter_params)).to eq({}), "#{invalid_filter}"
      end
    end
  end

  describe "visit count" do
    it "parses a visit_count filter" do
      valid_filter = { comparator: valid_visit_count_comparators.first, value: 5 }

      expected_filter = Filters::VisitCountFilter.new(valid_filter[:comparator], valid_filter[:value])

      filter_params = { visit_count: valid_filter.to_json }

      expect(parse_filters(filter_params)).to eq({ visit_count: expected_filter })
    end

    it "discards invalid visit_count filter comparators" do
      [
        { comparator: invalid_visit_count_comparators.first, value: 'bar' },
        { comparator: valid_visit_count_comparators.first, value: 'bar' },
        { comparator: valid_visit_count_comparators.first, value: nil },
        { comparator: valid_visit_count_comparators.first, value: '' },
        { comparator: valid_visit_count_comparators.first, value: -2 },
        { comparator: '', value: 'bar' },
        { comparator: nil, value: 'bar' },
        { value: 'bar' }
      ].each do |invalid_filter|
        filter_params = { visit_count: invalid_filter.to_json }

        expect(parse_filters(filter_params)).to eq({}), "#{invalid_filter}"
      end
    end
  end
end
