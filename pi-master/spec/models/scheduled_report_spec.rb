# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReport do
  before do
    travel_to Time.zone.local(2024, 7, 24, 12, 0, 0)

    Account.delete_all
    described_class.delete_all

    @account = create(:account)
    @valid_start_date = Time.current.beginning_of_minute + 2.minutes
  end

  after do
    travel_back
  end

  describe 'validation' do
    subject { scheduled_report.valid? }

    context 'when account_id is missing' do
      let(:scheduled_report) { build(:scheduled_report, account: nil) }

      it { is_expected.to be false }
    end

    context 'when name is missing' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, name: nil) }

      it { is_expected.to be false }
    end

    context 'when frequency is missing' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, frequency: nil) }

      it { is_expected.to be false }
    end

    context 'when date_range is missing' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, date_range: nil) }

      it { is_expected.to be false }
    end

    context 'when emails are duplicated' do
      let(:scheduled_report) { create(:scheduled_report_without_emails) }

      before do
        3.times { scheduled_report.scheduled_report_emails.new(email: 'test@test.com') }
      end

      it { is_expected.to be false }
    end

    context 'when start date is missing' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, start_date: nil) }

      it 'provides a default start_date' do
        expect(scheduled_report.valid?).to be true
        expect(scheduled_report.start_date).not_to be_nil
      end
    end

    context 'when start_date is in the past' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, start_date: @valid_start_date - 1.day) }

      it { is_expected.to be false }

      context 'when updating a record' do
        let(:scheduled_report) { create(:scheduled_report, account: @account, start_date: @valid_start_date) }
        let(:new_name) { "new_name" }

        it 'can be updated' do
          scheduled_report.update_columns(start_date: @valid_start_date - 1.day)
          expect(scheduled_report.valid?).to be true

          scheduled_report.update(name: new_name)
          expect(scheduled_report.valid?).to be true
          expect(scheduled_report.reload.name).to eq new_name
        end
      end
    end

    context 'when start_date is more specific than minutes' do
      let(:scheduled_report) { build(:scheduled_report, account: @account, start_date: @valid_start_date + 15.seconds) }

      it { is_expected.to be false }
    end

    context 'when surveys and groups are both empty and all survey is false' do
      let(:scheduled_report) { build(:scheduled_report_without_surveys, account: @account, start_date: @valid_start_date) }

      it { is_expected.to be false }
    end

    context 'when surveys are present' do
      let(:scheduled_report) { build(:scheduled_report_with_surveys, account: @account) }

      it { is_expected.to be true }
    end

    context 'when survey groups are present' do
      let(:scheduled_report) { build(:scheduled_report_with_survey_locale_group, account: @account) }

      it { is_expected.to be true }
    end
  end

  describe "all_surveys" do
    let(:scheduled_report) { create(:scheduled_report, account: @account) }

    context "when all_surveys is enabled" do
      before do
        scheduled_report.scheduled_report_survey_locale_groups.delete_all
        scheduled_report.scheduled_report_surveys.delete_all

        scheduled_report.surveys << create(:survey, account: @account)
        scheduled_report.survey_locale_groups << create(:survey_locale_group, account: @account)
        scheduled_report.scheduled_report_survey_locale_groups.first.surveys << create(:localized_survey, account: @account)

        scheduled_report.update(all_surveys: true)
      end

      it "destroys any associated scheduled_report_survey and scheduled_report_survey_locale_group records" do
        expect(scheduled_report.scheduled_report_surveys.count).to eq 0
        expect(scheduled_report.scheduled_report_survey_locale_groups.count).to eq 0
        expect(ScheduledReportSurvey.count).to eq 0
      end
    end
  end

  describe "skipping" do
    let(:scheduled_report) { create(:scheduled_report, account: @account) }

    it "is set up properly" do
      expect(scheduled_report.skip?).to be(false)
    end

    it "is skipped if it is in progress" do
      scheduled_report.update(in_progress: true)

      expect(scheduled_report.skip?).to be(true)
    end

    it "is skipped if it ran recently" do
      scheduled_report.update(last_attempt_at: Time.current)

      expect(scheduled_report.skip?).to be(true)
    end

    it "is skipped if it has no associated e-mails" do
      scheduled_report.scheduled_report_emails.delete_all
      scheduled_report.reload

      expect(scheduled_report.skip?).to be(true)
    end
  end

  describe "named date range parsing" do
    it "parses valid date range names" do
      valid_date_range_names = [:all_time, :one_month, :one_day, :year_to_date]

      valid_date_range_names.each do |named_date_range|
        scheduled_report = create(:scheduled_report, account: @account, date_range: named_date_range)

        now = Time.now.in_time_zone('GMT')
        end_time = now.yesterday.end_of_day

        expected_values = {
          all_time: nil,
          one_month: now.beginning_of_day - 30.days..end_time,
          one_week: now.beginning_of_day - 7.days..end_time,
          one_day: now.yesterday.beginning_of_day..end_time,
          year_to_date: now.beginning_of_year..end_time
        }

        expect(scheduled_report.parse_date_range).to eq(expected_values[named_date_range])
      end
    end
  end

  describe "send_next_report_at" do
    describe ".update_send_next_report_at" do
      subject { scheduled_report.send_next_report_at }

      before do
        scheduled_report.update_send_next_report_at
      end

      context "when frequency is daily" do
        let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :daily) }

        it { is_expected.to eq @valid_start_date + 1.day }
      end

      context "when frequency is weekly" do
        let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :weekly) }

        it { is_expected.to eq @valid_start_date + 1.week }
      end

      context "when frequency is biweekly" do
        let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :biweekly) }

        it { is_expected.to eq @valid_start_date + 2.weeks }
      end

      context "when frequency is monthly" do
        let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :monthly) }

        it { is_expected.to eq @valid_start_date + 1.month }
      end
    end

    describe "callbacks" do
      subject { scheduled_report.send_next_report_at }

      context "when creating a record" do
        let(:scheduled_report) { create(:scheduled_report, account: @account) }

        it { is_expected.not_to be_nil }
      end

      context "when next sending date exceeds end date" do
        before do
          scheduled_report.update_send_next_report_at
          scheduled_report.update frequency: :monthly
        end

        let(:scheduled_report) do
          create(:scheduled_report_with_account,
                 start_date: @valid_start_date,
                 end_date: @valid_start_date + 2.weeks,
                 frequency: :weekly)
        end

        it { is_expected.to be_nil }
      end

      context "when the report is in progress of sending" do
        let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :weekly, in_progress: true) }

        before do
          scheduled_report.update frequency: :monthly
        end

        it { is_expected.to eq @valid_start_date }
      end

      context "when start date and frequency are both updated" do
        let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :weekly) }

        before do
          scheduled_report.update frequency: :monthly, start_date: @valid_start_date + 1.day
        end

        it { is_expected.to eq @valid_start_date + 1.day }
      end

      context "when next sending date does't exceed end date and report isn't in progress and only frequency is updated" do
        before do
          scheduled_report.update_send_next_report_at
        end

        context "when frequency is changed to daily" do
          let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :weekly) }

          before do
            scheduled_report.update frequency: :daily
          end

          it { is_expected.to eq @valid_start_date + 1.day }
        end

        context "when frequency is changed to weekly" do
          let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :biweekly) }

          before do
            scheduled_report.update frequency: :weekly
          end

          it { is_expected.to eq @valid_start_date + 1.week }
        end

        context "when frequency is changed to biweekly" do
          let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :monthly) }

          before do
            scheduled_report.update frequency: :biweekly
          end

          it { is_expected.to eq @valid_start_date + 2.weeks }
        end

        context "when frequency is changed to monthly" do
          let(:scheduled_report) { create(:scheduled_report_with_account, start_date: @valid_start_date, frequency: :daily) }

          before do
            scheduled_report.update frequency: :monthly
          end

          it { is_expected.to eq @valid_start_date + 1.month }
        end
      end
    end
  end
end
