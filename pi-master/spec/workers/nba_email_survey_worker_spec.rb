# frozen_string_literal: true
require 'spec_helper'

describe NBAEmailSurveyWorker do
  let(:worker) { described_class.new }

  let(:report_filename) { "nba_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv" }
  let(:report_filepath) { "tmp/#{report_filename}" }
  let(:report_url) { FFaker::Internet.http_url }

  let(:data_start_date) { 1.day.ago.in_time_zone.beginning_of_day }
  let(:data_end_date) { data_start_date.end_of_day }

  let(:custom_report_filename) { "#{FFaker::Lorem.word}_#{FFaker::Lorem.word}" }
  let(:custom_report_filepath) { "tmp/#{custom_report_filename}" }

  # Required by periodic_worker_examples
  let(:aws_config) { {} }
  let(:aws_credentials) { {} }

  before do
    create(:account, id: 126, name: "NBA")

    delete_report_files
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.day.ago.beginning_of_day }
  end

  describe 'customization' do
    before do
      create_survey_in_report_scope(Account.first)
    end

    context "when a worker is provided with custom names" do
      before do
        allow(worker).to receive(:transfer_to_s3).and_return(FFaker::Internet.http_url)

        worker.perform(custom_report_filename: custom_report_filename)
      end

      it 'generates files with provided custom names' do
        expect(File.exist?(custom_report_filepath)).to be true
      end
    end
  end

  describe "dry runs" do
    before do
      create_survey_in_report_scope(Account.first)
    end

    it "allows for dry runs, i.e. that do not upload to the client" do
      expect(worker).not_to receive(:upload_to_nba)

      worker.perform(dry_run: true)
    end
  end

  def delete_report_files
    filepaths = [report_filepath, custom_report_filepath]
    FileUtils.rm_f(filepaths)
  end

  describe "ClientReportHistory" do
    let(:data_start_time) { 1.day.ago.beginning_of_day }

    context "when the report is successfully delivered" do
      before do
        job_class = described_class.new
        # TODO: Find less white box way of testing
        allow(job_class).to receive(:generate_submission_csv).and_return(true)

        job_class.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:send_answers).and_raise(StandardError)

        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end
end
