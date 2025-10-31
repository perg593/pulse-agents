# frozen_string_literal: true
require 'spec_helper'
include Control::DatesHelper

describe Control::DatesHelper do
  let(:now) { Time.now.in_time_zone('GMT') }

  it 'returns nil if params are nil' do
    expect(parse_date_range(nil, nil)).to be_nil
  end

  describe 'with from and to dates' do
    it 'returns nil if from cannot be parsed' do
      expect(parse_date_range('bad date', 'another bade date')).to be_nil
    end

    it 'returns the beginning and end of day' do
      ranges = parse_date_range('2017-01-22', '2017-01-26')
      zone = 'GMT'

      expected_from = ActiveSupport::TimeZone[zone].parse('2017-01-22')
      expected_to = ActiveSupport::TimeZone[zone].parse('2017-01-26')

      expect(ranges.first).to eq expected_from.beginning_of_day
      expect(ranges.last).to eq expected_to.end_of_day
    end

    it "interprets the provided times as GMT, disregarding any provided time zone" do
      start_date_string = '2017-01-22 00:00:00'
      end_date_string = '2017-01-26 23:59:00'
      user_time_zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]

      system_time_zone = ActiveSupport::TimeZone["GMT"]
      expected_from = system_time_zone.parse(start_date_string)
      expected_to = system_time_zone.parse(end_date_string)

      range = parse_date_range(user_time_zone.parse(start_date_string).to_s, user_time_zone.parse(end_date_string).to_s)

      expect(range).not_to be_nil
      expect(range.first).to eq expected_from.beginning_of_day
      expect(range.last).to eq expected_to.end_of_day
    end
  end

  describe 'with date_range' do
    describe 'Timezone' do
      context 'when from and to are specified' do
        context 'when it is Daylight Saving Time' do
          it 'returns dates in GMT' do
            expect_time_range_in_utc(parse_date_range('2020-8-1', '2020-8-2'))
          end
        end

        context 'when it is not Daylight Saving Time' do
          it 'returns dates in GMT' do
            expect_time_range_in_utc(parse_date_range('2020-1-1', '2020-1-2'))
          end
        end
      end

      def expect_time_range_in_utc(range)
        utc_zone_values = ["UTC", "+00:00"]

        expect(utc_zone_values.include?(range.first.zone)).to be true
        expect(utc_zone_values.include?(range.last.zone)).to be true
      end
    end
  end
end
