# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReportCheckupWorker do
  describe 'e-mail delivery' do
    before do
      @scheduled_report = create(:scheduled_report, end_date: nil, send_next_report_at: 1.minute.ago)
      @scheduled_report.start_date = 1.minute.ago.beginning_of_minute
      @scheduled_report.save(validate: false)
    end

    it 'sends no e-mail when no scheduled reports are stuck in_progress' do
      @scheduled_report.update(in_progress: false)

      expect do
        described_class.new.perform
      end.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'sends an e-mail when a ScheduledReport is stuck in_progress' do
      @scheduled_report.update(in_progress: true, updated_at: 11.minutes.ago)

      expect do
        described_class.new.perform
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'does not send an e-mail if a ScheduledReport was put in_progress just before this executed' do
      @scheduled_report.update(in_progress: true)

      expect do
        described_class.new.perform
      end.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'sends an e-mail if a ScheduledReport was skipped' do
      create(:scheduled_report_email, scheduled_report_id: @scheduled_report.id)
      @scheduled_report.in_progress = false
      @scheduled_report.last_attempt_at = nil
      @scheduled_report.all_surveys = true
      @scheduled_report.send_next_report_at = 1.hour.ago
      @scheduled_report.save

      # The worker doesn't recognize @scheduled_report
      ScheduledReport.any_instance.stub(:skip?).and_return(true) # rubocop:disable RSpec/AnyInstance
      ScheduledReport.any_instance.stub(:skip_reasons).and_return([[:reason_a, FFaker::Lorem.phrase], [:reason_b, FFaker::Lorem.phrase]]) # rubocop:disable RSpec/AnyInstance

      ActionMailer::Base.deliveries.clear

      expect do
        described_class.new.perform
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      email_body = ActionMailer::Base.deliveries.last.body

      @scheduled_report.skip_reasons.each do |(_code, reason)|
        expect(email_body).to include reason
      end
    end

    it 'sends an e-mail when a ScheduledReport that was due for processing was not processed' do
      # i.e. send_next_report_at < 10.minutes.ago, which is the interval that the scheduled report worker runs on
      @scheduled_report.update(send_next_report_at: 11.minutes.ago, in_progress: false)

      expect do
        described_class.new.perform
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
