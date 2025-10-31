# frozen_string_literal: true

RSpec.shared_examples "filter sharing" do
  let(:for_endpoint) { false }

  # Creates one or more record(s) that will match the filter
  # @param filter_attribute - the db attribute being filtered on
  # @param attribute_value - the value for that attribute
  def make_records(_filter_attribute = nil, _attribute_value = nil)
    raise NotImplementedError, "You must implement 'make_records' to use 'filter sharing'"
  end

  # Compares results filtered by filters
  # @param filters - hash of filters (see filters_helper)
  def it_filters(_filters)
    raise NotImplementedError, "You must implement 'it_filters' to use 'filter sharing'"
  end

  describe "unfiltered" do
    it "returns the number of associated answers" do
      make_records
      it_filters({})
    end
  end

  describe "date ranges" do
    # Users may specify date ranges in any time zone, which
    # must then be interpreted as GMT.
    describe "Arbitrary time zone" do
      before do
        # arbitrary non-GMT time zone
        user_time_zone = ActiveSupport::TimeZone["America/Vancouver"]

        @start_time = user_time_zone.parse("2022-01-13 00:00:00")
        @end_time = user_time_zone.parse("2022-01-13 23:59:59")

        out_of_range_times = [
          "2022-01-14 00:00:00" # in PST/PDT range
        ]

        in_range_times = [
          "2022-01-13 00:00:00", # out of PST/PDT range
          "2022-01-13 12:00:00"
        ]

        (out_of_range_times + in_range_times).each do |creation_time|
          make_records(:created_at, creation_time.to_datetime)
        end
      end

      it "returns the number of associated answers for the specified date range" do
        filters = { date_range: @start_time..@end_time }

        it_filters(filters)
      end
    end
  end

  describe "possible_answer_id" do
    context "when provided a single possible_answer_id" do
      it "returns answers belonging to submissions associated with that possible_answer_id" do
        possible_answer_id = 42

        # REQUIRES:
        # one answer with this possible_answer_id -- included in results
        # one answer for the same submission for a different question -- included in results
        # one answer for a different submission -- excluded from results
        make_records(:possible_answer_id, possible_answer_id)

        filters = { possible_answer_id: possible_answer_id }

        it_filters(filters)
      end
    end
  end

  describe "pageview count" do
    let(:value) { 40 }

    def format_pageview_count_filter(filter)
      for_endpoint ? filter.to_json : filter
    end

    before do
      make_records(:pageview_count, 1)
      make_records(:pageview_count, 42)

      filter = Filters::PageviewCountFilter.new(comparator, value)

      @filters = { pageview_count: format_pageview_count_filter(filter) }
    end

    context "when less than" do
      let(:comparator) { "less_than" }

      it "returns the number of associated answers for the pageview_count" do
        it_filters(@filters)
      end
    end

    context "when less than or equal to" do
      let(:comparator) { "less_than_or_equal_to" }

      it "returns the number of associated answers for the pageview_count" do
        it_filters(@filters)
      end
    end

    context "when equal to" do
      let(:comparator) { "equal_to" }
      let(:value) { 42 }

      it "returns the number of associated answers for the pageview_count" do
        it_filters(@filters)
      end
    end

    context "when greater than or equal to" do
      let(:comparator) { "greater_than_or_equal_to" }

      it "returns the number of associated answers for the pageview_count" do
        it_filters(@filters)
      end
    end

    context "when greater than" do
      let(:comparator) { "greater_than" }

      it "returns the number of associated answers for the pageview_count" do
        it_filters(@filters)
      end
    end
  end

  describe "visit count" do
    let(:value) { 40 }

    def format_visit_count_filter(filter)
      for_endpoint ? filter.to_json : filter
    end

    before do
      make_records(:visit_count, 1)
      make_records(:visit_count, 42)

      filter = Filters::VisitCountFilter.new(comparator, value)

      @filters = { visit_count: format_visit_count_filter(filter) }
    end

    context "when less than" do
      let(:comparator) { "less_than" }

      it "returns the number of associated answers for the visit_count" do
        it_filters(@filters)
      end
    end

    context "when less than or equal to" do
      let(:comparator) { "less_than_or_equal_to" }

      it "returns the number of associated answers for the visit_count" do
        it_filters(@filters)
      end
    end

    context "when equal to" do
      let(:comparator) { "equal_to" }
      let(:value) { 42 }

      it "returns the number of associated answers for the visit_count" do
        it_filters(@filters)
      end
    end

    context "when greater than or equal to" do
      let(:comparator) { "greater_than_or_equal_to" }

      it "returns the number of associated answers for the visit_count" do
        it_filters(@filters)
      end
    end

    context "when greater than" do
      let(:comparator) { "greater_than" }

      it "returns the number of associated answers for the visit_count" do
        it_filters(@filters)
      end
    end
  end

  describe "device types" do
    it "returns the number of associated answers for the specified device" do
      target_device = "desktop"
      ignored_device = "mobile"

      make_records(:device_type, target_device)
      make_records(:device_type, ignored_device)

      filters = { device_types: [target_device] }

      it_filters(filters)
    end

    it "returns the number of associated answers for an array of specified devices" do
      target_devices = %w(desktop tablet)
      ignored_device = "mobile"

      target_devices.each { |target_device| make_records(:device_type, target_device) }
      make_records(:device_type, ignored_device)

      filters = { device_types: target_devices }

      it_filters(filters)
    end
  end

  describe "completion url" do
    def format_completion_url_filters(completion_url_filters)
      filters = Array.wrap(completion_url_filters)
      filters = filters.map(&:to_json) if for_endpoint
      filters
    end

    it "returns the number of associated answers for a 'contains' filter" do
      make_records(:url, 'alpha')
      make_records(:url, 'xyz')

      completion_url_filter = CompletionUrlFilter.new('contains', 'p', cumulative: false) # matches 'alpha'

      filters = { completion_urls: format_completion_url_filters(completion_url_filter) }

      it_filters(filters)
    end

    it "returns the number of associated answers for a 'does_not_contain' filter" do
      make_records(:url, 'alpha')
      make_records(:url, 'xyz')

      completion_url_filter = CompletionUrlFilter.new('does_not_contain', 'y', cumulative: false) # matches 'alpha'

      filters = { completion_urls: format_completion_url_filters(completion_url_filter) }

      it_filters(filters)
    end

    it "returns the number of associated answers for a 'regex' filter" do
      make_records(:url, 'alpha')
      make_records(:url, 'xyz')

      completion_url_filter = CompletionUrlFilter.new('regex', 'a.p.a', cumulative: false) # matches 'alpha'

      filters = { completion_urls: format_completion_url_filters(completion_url_filter) }

      it_filters(filters)
    end

    it "returns the number of associated answers for non-cumulative filters" do
      make_records(:url, 'alpha')
      make_records(:url, 'xyz')
      make_records(:url, '123.com')

      completion_url_filters = [
        CompletionUrlFilter.new('contains', 'p', cumulative: false), # matches 'alpha'
        CompletionUrlFilter.new('contains', '2', cumulative: false)  # matches '123.com'
      ]

      filters = { completion_urls: format_completion_url_filters(completion_url_filters) }

      it_filters(filters)
    end

    it "returns the number of associated answers for cumulative filters" do
      make_records(:url, 'alpha')
      make_records(:url, 'beta')

      completion_url_filters = [
        CompletionUrlFilter.new('contains', 'a', cumulative: true), # matches 'alpha', 'beta'
        CompletionUrlFilter.new('contains', 'p', cumulative: true)  # matches 'alpha'
      ]

      filters = { completion_urls: format_completion_url_filters(completion_url_filters) }

      it_filters(filters)
    end

    it "returns the number of associated answers for a mix of cumulative and non-cumulative filters" do
      make_records(:url, 'alpha')
      make_records(:url, 'beta')

      completion_url_filters = [
        CompletionUrlFilter.new('contains', 'a', cumulative: false), # matches 'alpha', 'beta'
        CompletionUrlFilter.new('contains', 'p', cumulative: false), # matches 'alpha'
        CompletionUrlFilter.new('contains', 'b', cumulative: true), # matches 'beta'
        CompletionUrlFilter.new('contains', 't', cumulative: true) # matches 'beta'
      ]

      filters = { completion_urls: format_completion_url_filters(completion_url_filters) }

      it_filters(filters)
    end
  end
end
