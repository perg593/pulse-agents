# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleanupSubmissionsMailer do
  describe "daily_report_email" do
    let!(:emails) { %w(foo@sample.com foo2@sample.com) }
    let!(:data) { [{ udid: 'c773f899-49c7-45cd-a0bb-2ae1552d2dda', count: 3, user_agent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X)' }] }
    let(:mail) { described_class.daily_report_email(emails, data) }

    before do
      travel_to Time.zone.local(2019, 1, 1)
    end

    after do
      travel_back
    end

    it "renders the headers" do
      expect(mail.subject).to eq '[Pulse Insights] daily impressions deletion'
      expect(mail.to).to eq emails
      expect(mail.from.first).to eq Rails.application.credentials.mailer[:mailer_sender].match(/<(.*)>/)[1]
    end

    it "renders the body" do
      expect(mail.body.encoded.gsub(/>(\n|\s)*</, '><').strip).to match file_fixture('daily_report_email.html').read.gsub(/>(\n|\s)*</, '><').strip
    end

    it "queues emails" do
      # NOTE: there seems to be no way to simply test mail queueing with rspec.
      # Mailer spec is a thin wrapper for ActionMailer::TestCase, so a MiniTest method is used here.
      assert_emails 1 do
        mail.deliver_now
      end
    end
  end
end
