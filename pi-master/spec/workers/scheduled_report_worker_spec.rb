# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReportWorker do
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    ScheduledReport.delete_all
    ScheduledReportEmail.delete_all
    ScheduledReportSurvey.delete_all
    Sidekiq::Worker.clear_all
    Sidekiq::Queue.new.clear

    @valid_start_date = Time.current.beginning_of_minute + 2.minutes
  end

  describe 'A ScheduledReport' do
    it 'does not queue a job that should be skipped' do
      scheduled_report = create(:scheduled_report_with_account)

      # The worker doesn't recognize @scheduled_report
      ScheduledReport.any_instance.stub(:skip?).and_return(true) # rubocop:disable RSpec/AnyInstance

      run_job

      expect_not_to_queue
    end

    it 'does not queue a job to run before start_date' do
      create(:scheduled_report_with_account, start_date: @valid_start_date + 1.hour)

      run_job

      expect_not_to_queue
    end

    it 'queues a job to run after start_date' do
      execute_in_past { create(:scheduled_report_with_account, start_date: @valid_start_date) }

      run_job

      expect_to_queue
    end

    it 'queues a job to run at updated start_date' do
      scheduled_report = create(:scheduled_report_with_account, start_date: @valid_start_date + 1.week)

      scheduled_report.update(start_date: @valid_start_date + 1.minute)

      run_job

      expect_to_queue
    end

    it 'queues a job to run at updated start_date even if ahead of original send_next_report_date' do
      execute_in_past do
        @scheduled_report = create(:scheduled_report_with_account)
      end

      @scheduled_report.update(start_date: @valid_start_date)

      run_job

      expect_to_queue
    end

    it 'queues a job to run before end_date' do
      create(:scheduled_report_with_account, end_date: 1.week.from_now)

      run_job

      expect_to_queue
    end

    it 'does not queue a job to run after end_date' do
      end_date = 1.week.ago

      create(:scheduled_report_with_account, end_date: end_date)

      run_job

      expect_not_to_queue
    end

    it 'does not queue a job to run if send_next_report_at is same day but in the future' do
      scheduled_report = create(:scheduled_report_with_account)

      send_next_report_at = scheduled_report.start_date + 1.hour
      scheduled_report.update(send_next_report_at: send_next_report_at)

      run_job

      expect_not_to_queue
    end

    it 'queues a job to run if created without end_date' do
      scheduled_report = create(:scheduled_report_with_account)

      expect(scheduled_report.reload.send_next_report_at).to be_within(1.second).of scheduled_report.start_date

      run_job

      expect_to_queue
    end

    it 'queues a job to run if created with an end_date in the future' do
      end_date = 3.months.from_now

      create(:scheduled_report_with_account, end_date: end_date)

      run_job

      expect_to_queue
    end

    it 'queues a job to run if there is a survey' do
      create(:scheduled_report)

      run_job

      expect_to_queue
    end

    it 'queues a job to run if there is a survey group' do
      create(:scheduled_report_with_survey_locale_group)

      run_job

      expect_to_queue
    end

    it 'does not queue a job to run if it already ran in the last 23hrs' do
      travel_to (23.hours + 1.minute).ago
      scheduled_report = create(:scheduled_report)
      IndividualScheduledReportWorker.new.perform(scheduled_report.id)
      travel_back

      run_job

      expect_not_to_queue
    end

    it 'queues a job to run if it ran more than 23hrs ago' do
      travel_to 1.day.ago
      scheduled_report = create(:scheduled_report)
      IndividualScheduledReportWorker.new.perform(scheduled_report.id)
      travel_back

      run_job

      expect_to_queue
    end

    describe "paused" do
      context "when report is paused" do
        before do
          create(:scheduled_report, paused: true)
        end

        it 'does not queue a job to run' do
          run_job
          expect_not_to_queue
        end
      end

      context "when report is not paused" do
        before do
          create(:scheduled_report, paused: false)
        end

        it 'queues a job to run' do
          run_job
          expect_to_queue
        end
      end
    end
  end

  describe 'Send scheduled report frequently' do
    subject { IndividualScheduledReportWorker.jobs.size }

    before do
      IndividualScheduledReportWorker.new.perform(scheduled_report.id)
    end

    context "when frequency is daily" do
      let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :daily) }

      context "when it hasn't been a day yet" do
        before do
          execute_scheduled_report_worker_at 12.hours.from_now
        end

        it { is_expected.to eq 0 }
      end

      context "when it's been over a day" do
        before do
          execute_scheduled_report_worker_at 30.hours.from_now
        end

        it { is_expected.to eq 1 }
      end
    end

    context "when frequency is weekly" do
      let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :weekly) }

      context "when it hasn't been a week yet" do
        before do
          execute_scheduled_report_worker_at 2.days.from_now
        end

        it { is_expected.to eq 0 }
      end

      context "when it's been over a week" do
        before do
          execute_scheduled_report_worker_at 8.days.from_now
        end

        it { is_expected.to eq 1 }
      end
    end

    context "when frequency is biweekly" do
      let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :biweekly) }

      context "when it hasn't been two weeks yet" do
        before do
          execute_scheduled_report_worker_at 1.week.from_now
        end

        it { is_expected.to eq 0 }
      end

      context "when it's been over two weeks" do
        before do
          execute_scheduled_report_worker_at 15.days.from_now
        end

        it { is_expected.to eq 1 }
      end
    end

    context "when frequency is monthly" do
      let(:scheduled_report) { create(:scheduled_report_with_account, frequency: :monthly) }

      context "when it hasn't been one month yet" do
        before do
          execute_scheduled_report_worker_at 3.weeks.from_now
        end

        it { is_expected.to eq 0 }
      end

      context "when it's been over one month" do
        before do
          execute_scheduled_report_worker_at 40.days.from_now
        end

        it { is_expected.to eq 1 }
      end
    end
  end

  def expect_to_queue
    expect(IndividualScheduledReportWorker.jobs.size).to eq(1)
  end

  def expect_not_to_queue
    expect(IndividualScheduledReportWorker.jobs.size).to eq(0)
  end

  def run_job
    execute_in_future { described_class.new.perform }
  end

  def execute_in_past(&block)
    travel_to 10.minutes.ago
    block.call
    travel_back
  end

  def execute_in_future(&block)
    travel_to 10.minutes.from_now
    block.call
    travel_back
  end

  def execute_scheduled_report_worker_at(time)
    travel_to time
    ScheduledReportWorker.new.perform
    travel_back
  end
end
