# frozen_string_literal: true

RSpec.shared_examples "status logger logs success" do
  it "creates a ClientReportHistory record" do
    expect(ClientReports::ClientReportHistory.count).to eq(1)

    client_report_history = ClientReports::ClientReportHistory.first

    expect(client_report_history.job_class).to eq(described_class.name.underscore)
    expect(client_report_history.data_start_time).to eq(data_start_time)
    expect(client_report_history.status).to eq("succeeded")
  end
end

RSpec.shared_examples "status logger logs failure" do
  it "creates a ClientReportHistory record" do
    expect(ClientReports::ClientReportHistory.count).to eq(1)

    client_report_history = ClientReports::ClientReportHistory.first

    expect(client_report_history.job_class).to eq(described_class.name.underscore)
    expect(client_report_history.data_start_time).to eq(data_start_time)
    expect(client_report_history.status).to eq("failed")
  end
end
