# frozen_string_literal: true
require 'spec_helper'

describe AstraZenecaAggregateWorker do
  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.day.ago.beginning_of_day }
  end

  describe "ClientReportHistory" do
    let(:data_start_time) { 1.day.ago.beginning_of_day }

    context "when the report is successfully delivered" do
      before do
        described_class.new.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:transfer_to_s3).and_raise(StandardError)

        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end
end
