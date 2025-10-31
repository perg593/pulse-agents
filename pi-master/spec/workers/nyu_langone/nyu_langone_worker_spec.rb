# frozen_string_literal: true
require 'spec_helper'

describe NYULangone::NYULangoneWorker do
  describe "ClientReportHistory" do
    let(:data_start_time) { 1.day.ago.beginning_of_day }

    before do
      account = create(:account, identifier: NYULangone::NYU_LANGONE_ACCOUNT_IDENTIFIER)
      create(:survey, account: account)
    end

    context "when the report is successfully delivered" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:upload_to_nyu_langone)

        job_class.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:generate_submission_csv).and_raise(StandardError)

        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.day.ago.beginning_of_day }
  end
end
