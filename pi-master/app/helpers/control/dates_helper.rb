# frozen_string_literal: true
module Control
  module DatesHelper
    def parse_date_range(from, to)
      return nil if from.blank? && to.blank?

      range = [
        from.to_datetime.beginning_of_day,
        to.to_datetime.end_of_day
      ].map { |datetime_string| datetime_string.to_datetime.change(offset: "+0000") } # UTC+0

      return range.first..range.last
    rescue StandardError => e
      nil
    end

    def pi_formatted_date(datetime)
      result = <<-HTML
        <span class='pi-formatted-date'>
          #{datetime.to_i * 1000}
        </span>
      HTML

      result.html_safe
    end
  end
end
