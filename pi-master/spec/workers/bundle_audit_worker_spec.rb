# frozen_string_literal: true
require 'spec_helper'

describe BundleAuditWorker do
  let(:worker) { described_class.new }

  before do
    allow(worker).to receive(:update_vulnerability_db)
  end

  describe "report delivery" do
    context "when at least one vulnerability was detected" do
      let(:mock_data) { [build(:bundle_audit_result)] }

      before do
        allow(worker).to receive(:check_for_vulnerabilities).and_raise SystemExit
        allow(worker).to receive(:parse_results).with("audit_output.json").and_return mock_data
      end

      it "sends an e-mail" do
        expect(DeveloperNotificationMailer).to receive(:bundle_audit_vulnerabilities_detected).with(mock_data).and_call_original

        worker.perform
      end
    end

    context "when no vulnerabilities were detected" do
      before do
        allow(worker).to receive(:check_for_vulnerabilities).with("audit_output.json").and_return nil
      end

      it "does not send an e-mail" do
        expect do
          worker.perform
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
