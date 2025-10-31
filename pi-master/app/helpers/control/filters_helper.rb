# frozen_string_literal: true
module Control
  module FiltersHelper
    VALID_COMPLETION_URL_MATCHERS = %w(contains does_not_contain regex).freeze

    def parse_filters(filter_params)
      return {} unless filter_params.present?

      {
        device_types: parse_device_types(filter_params),
        date_range: namespaced_parse_date_range(filter_params),
        possible_answer_id: parse_possible_answers(filter_params),
        market_ids: parse_markets(filter_params),
        completion_urls: parse_completion_urls(filter_params),
        pageview_count: Filters::PageviewCountFilter.from_params(filter_params[:pageview_count]),
        visit_count: Filters::VisitCountFilter.from_params(filter_params[:visit_count])
      }.compact_blank
    end

    private

    def parse_device_types(filter_params)
      Submission::VALID_DEVICE_TYPES & Array.wrap(filter_params[:device_types])
    end

    def parse_markets(filter_params)
      Array.wrap(filter_params[:market_ids]).map(&:to_i).select(&:positive?)
    end

    def parse_possible_answers(filter_params)
      filter_val = filter_params[:possible_answer_id].to_i

      return filter_val if filter_val.positive?
    end

    # TODO: Stop using mixin and use something else, perhaps a plain old
    # ruby object.
    def namespaced_parse_date_range(filter_params)
      result = if filter_params[:date_range].is_a?(Range)
        [filter_params[:date_range].first, filter_params[:date_range].last]
      elsif filter_params[:date_range].is_a?(String)
        filter_params[:date_range].split("..")
      else
        [filter_params[:from], filter_params[:to]]
      end

      time_zone_offset = "+0000" # UTC+0
      result.map!(&:to_datetime)
      result.map! { |datetime| datetime.change(offset: time_zone_offset) }

      (result.first..result.last)
    rescue NoMethodError, Date::Error => e
      Rails.logger.info "Ignoring invalid date, #{filter_params[:date_range]}"
      nil
    end

    def parse_completion_urls(filter_params)
      completion_url_filters = []

      filter_params[:completion_urls]&.each do |completion_url|
        completion_url = JSON.parse(completion_url, symbolize_names: true)

        next unless VALID_COMPLETION_URL_MATCHERS.include?(completion_url[:matcher])
        next unless completion_url[:value].to_s.present?
        next unless [true, false].include?(completion_url[:cumulative])

        completion_url_filters << CompletionUrlFilter.new(
          completion_url[:matcher], completion_url[:value].to_s, cumulative: (completion_url[:cumulative].to_s.downcase == "true")
        )
      end

      completion_url_filters
    end
  end
end
