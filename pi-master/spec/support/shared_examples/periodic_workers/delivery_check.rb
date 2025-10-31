# frozen_string_literal: true

RSpec.shared_examples "delivery check" do
  let(:default_data_start_time) { nil }

  context "when there is a ClientReportHistory for the default data start time marked as success" do
    let(:data_start_time) { default_data_start_time }

    before do
      create(
        :client_report_history,
        status: :succeeded,
        job_class: described_class.name.underscore,
        data_start_time: data_start_time
      )
    end

    it "is considered delivered" do
      expect(described_class.delivered_as_expected?).to be(true)
    end
  end

  context "when there is a ClientReportHistory for a given data start time marked as success" do
    let(:data_start_time) { FFaker::Time.datetime }

    before do
      create(
        :client_report_history,
        status: :succeeded,
        job_class: described_class.name.underscore,
        data_start_time: data_start_time
      )
    end

    it "is considered delivered" do
      expect(described_class.delivered_as_expected?(data_start_time)).to be(true)
    end
  end

  context "when there is no ClientReportHistory for a given data start time marked as success" do
    let(:data_start_time) { FFaker::Time.datetime }

    context "when marked as failed" do
      before do
        create(
          :client_report_history,
          status: :failed,
          job_class: described_class.name.underscore,
          data_start_time: data_start_time
        )
      end

      it "is not considered delivered" do
        expect(described_class.delivered_as_expected?(data_start_time)).to be(false)
      end
    end

    context "when for a different data start time" do
      before do
        create(
          :client_report_history,
          status: :succeeded,
          job_class: described_class.name.underscore,
          data_start_time: data_start_time - 1.hour
        )
      end

      it "is not considered delivered" do
        expect(described_class.delivered_as_expected?(data_start_time)).to be(false)
      end
    end
  end
end
