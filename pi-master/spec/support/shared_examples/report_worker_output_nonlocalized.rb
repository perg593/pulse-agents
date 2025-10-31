# frozen_string_literal: true

RSpec.shared_examples "report worker output for non-localized survey" do
  describe "returns an accurate xlsx file" do
    it 'returns an accurate xlsx file' do
      # "Survey metadata", "Aggregate results by day", "Questions", "Individual rows" and "Devices"
      expect(@xlsx_package.workbook.worksheets.count).to eq 5
    end

    it 'returns an accurate report overview sheet' do
      worksheet = report_overview_summary_by_day_worksheet(@xlsx_package)
      accurate_report_overview_sheet(survey, worksheet)
    end

    it 'returns an accurate stats summary by day sheet' do
      worksheet = summary_by_day_worksheet(@xlsx_package)
      accurate_summary_by_day_sheet(survey, worksheet, date_format: "%m/%d/%y")
    end

    it 'returns an accurate response summaries sheet' do
      worksheet = response_summaries_worksheet(@xlsx_package)
      accurate_response_summaries_sheet(survey, worksheet)
    end

    it 'returns an accurate individual responses sheet' do
      worksheet = individual_responses_worksheet(@xlsx_package)
      accurate_individual_responses_sheet(survey, worksheet)
    end

    it 'returns an accurate responses by device sheet' do
      worksheet = device_worksheet(@xlsx_package)
      accurate_responses_by_device_sheet(survey, worksheet)
    end
  end
end
