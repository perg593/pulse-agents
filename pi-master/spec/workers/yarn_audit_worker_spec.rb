# frozen_string_literal: true
require 'spec_helper'

describe YarnAuditWorker do
  let(:worker) { described_class.new }

  describe "report delivery" do
    context "when at least one vulnerability was detected" do
      let(:mock_data) { {"something" => "not_sure_yet"} }

      before do
        allow(worker).to receive(:check_for_vulnerabilities).and_return(mock_data)
      end

      it "sends an e-mail" do
        expect(DeveloperNotificationMailer).to receive(:yarn_audit_vulnerabilities_detected).with(mock_data).and_call_original

        worker.perform
      end
    end

    context "when no vulnerabilities were detected" do
      before do
        allow(worker).to receive(:check_for_vulnerabilities).and_return []
      end

      it "does not send an e-mail" do
        expect do
          worker.perform
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
