# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReportEmail do
  before do
    described_class.delete_all
    ScheduledReport.delete_all
  end

  let(:scheduled_report) { create(:scheduled_report_without_emails) }
  let(:scheduled_report_email) { described_class.new(scheduled_report: scheduled_report, email: email_address) }

  describe "validations" do
    context "when the e-mail address is blank" do
      let(:bad_email_addresses) { ["", " "] }

      it "the record is invalid" do
        bad_email_addresses.each do |bad_email_address|
          scheduled_report_email = described_class.new(scheduled_report: scheduled_report, email: bad_email_address)

          expect(scheduled_report_email.valid?).to be false
          expect(scheduled_report_email.errors.details).to eq(email: [{error: :blank}])
        end
      end
    end

    context "when the e-mail address is invalid" do
      let(:email_address) { "invalid email" }

      it "the record is in valid" do
        expect(scheduled_report_email.valid?).to be false
        expect(scheduled_report_email.errors.details).to eq(email: [{error: "is not an e-mail address"}])
      end
    end

    context "when the e-mail address already exists in the database" do
      let(:email_address) { "test@test.com" }

      before do
        described_class.create(scheduled_report: scheduled_report, email: email_address)
      end

      it "the record is invalid" do
        expect(scheduled_report_email.valid?).to be false
        expect(scheduled_report_email.errors.details).to eq(email: [error: :taken, value: email_address])
      end
    end
  end

  context "when the e-mail address contains whitespace" do
    let(:email_address) { " \t   test@test.com    \n\r" }

    it "strips whitespaces, etc. from email" do
      expect(scheduled_report_email.valid?).to be true
      expect(scheduled_report_email.email).to eq email_address.strip
    end
  end
end
