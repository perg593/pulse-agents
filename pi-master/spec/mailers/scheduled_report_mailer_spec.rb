# frozen_string_literal: true

require "spec_helper"

RSpec.describe ScheduledReportMailer do
  describe "#send_report" do
    let(:scheduled_report) { create(:scheduled_report_with_surveys) }
    let(:report_id) { scheduled_report.id }
    let(:report_name) { scheduled_report.name }
    let(:emails) { [FFaker::Internet.email] }
    let(:date) { Time.current }
    let(:human_date_range) { "Something" }
    let(:report_csv_urls) { { locale_groups: {}, surveys: {} } }
    let(:report_result_counts) do
      {
        locale_groups: {},
        surveys: {
          scheduled_report.surveys.first.id => 42
        }
      }
    end

    context "when all surveys in the report have a report URL" do
      let(:report_xlsx_urls) do
        {
          locale_groups: {},
          surveys: {
            scheduled_report.surveys.first.id => "some_url"
          }
        }
      end

      it "sends an e-mail" do
        described_class.send_report(report_xlsx_urls, emails, report_name, report_id, date, report_csv_urls, report_result_counts, human_date_range).deliver_now
      end
    end

    context "when one of the surveys has no report URL" do
      let(:report_xlsx_urls) do
        {
          locale_groups: {},
          surveys: {
            scheduled_report.surveys.first.id => "some_url",
            scheduled_report.surveys.last.id => nil
          }
        }
      end

      let(:report_result_counts) do
        {
          locale_groups: {},
          surveys: {
            scheduled_report.surveys.first.id => 42,
            scheduled_report.surveys.last.id => 0
          }
        }
      end

      before do
        scheduled_report.surveys << create(:survey, account: scheduled_report.account)
      end

      it "sends an e-mail" do
        described_class.send_report(report_xlsx_urls, emails, report_name, report_id, date, report_csv_urls, report_result_counts, human_date_range).deliver_now
      end
    end
  end
end
