# frozen_string_literal: true
require 'spec_helper'

describe PeriodicReportWorkers::BenMooreWorker do
  let(:worker) { described_class.new }

  let(:qc_filename) { "benjaminmoore_pulseinsights_qc_#{Time.current.strftime("%y%m%d")}.csv" }
  let(:qc_filepath) { "tmp/#{qc_filename}" }
  let(:qc_url) { FFaker::Internet.http_url }

  let(:report_filename) { "benjaminmoore_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv" }
  let(:report_filepath) { "tmp/#{report_filename}" }
  let(:report_url) { FFaker::Internet.http_url }

  let(:data_start_date) { 1.month.ago.in_time_zone.beginning_of_month }
  let(:data_end_date) { data_start_date.end_of_month }

  let(:custom_report_filename) { "#{FFaker::Lorem.word}_#{FFaker::Lorem.word}" }
  let(:custom_qc_filename) { "#{FFaker::Lorem.word}_#{FFaker::Lorem.word}" }
  let(:custom_report_filepath) { "tmp/#{custom_report_filename}" }
  let(:custom_qc_filepath) { "tmp/#{custom_qc_filename}" }

  let(:aws_config) do
    {
      region: "us-west-2",
      bucket_path: "",
      bucket_name: "pi-reports"
    }
  end

  let(:aws_credentials) { Aws.config[:credentials] }

  before do
    allow(worker).to receive(:transfer_to_s3).with(qc_filename, aws_config, credentials: aws_credentials).and_return qc_url
    allow(worker).to receive(:transfer_to_s3).with(report_filename, aws_config, credentials: aws_credentials).and_return report_url

    create(:account, id: 174, name: "Benjamin Moore")

    delete_report_files
  end

  describe "quality control file" do
    it_behaves_like "quality_control_file" do
      let(:qc_filename) { "benjaminmoore_pulseinsights_qc_#{Time.current.strftime("%y%m%d")}.csv" }
      let(:qc_filepath) { "tmp/#{qc_filename}" }
      let(:report_filename) { "benjaminmoore_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv" }
      let(:report_filepath) { "tmp/#{report_filename}" }
      let(:report_data_range) { data_start_date..data_end_date }
    end
  end

  describe "report file" do
    it_behaves_like "submission_report_file" do
      let(:report_filename) { "benjaminmoore_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv" }
      let(:report_filepath) { "tmp/#{report_filename}" }
    end
  end

  describe 'historical file generation' do
    it_behaves_like "historical_report" do
      let(:qc_filename) { "benjaminmoore_pulseinsights_qc_#{Time.current.strftime("%y%m%d")}.csv" }
      let(:qc_filepath) { "tmp/#{qc_filename}" }

      let(:report_filename) { "benjaminmoore_pulseinsights_data_#{Time.current.strftime("%y%m%d")}.csv" }
      let(:report_filepath) { "tmp/#{report_filename}" }
    end
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.month.ago.beginning_of_month }
  end

  describe 'customization' do
    context "when a worker is provided with custom names" do
      before do
        allow(worker).to receive(:transfer_to_s3).and_return(FFaker::Internet.http_url)

        worker.perform(custom_report_filename: custom_report_filename, custom_qc_filename: custom_qc_filename)
      end

      it 'generates files with provided custom names' do
        expect(File.exist?(custom_report_filepath)).to be true
        expect(File.exist?(custom_qc_filepath)).to be true
      end
    end
  end

  describe "report upload" do
    it "transfers files to s3" do
      allow(worker).to receive(:transfer_to_s3).and_return(FFaker::Internet.http_url)

      expect(worker).to receive(:transfer_to_s3).with(report_filename, aws_config, credentials: aws_credentials)
      expect(worker).to receive(:transfer_to_s3).with(qc_filename, aws_config, credentials: aws_credentials)

      worker.perform
    end
  end

  describe "notification to PI" do
    before do
      ActionMailer::Base.deliveries.clear
    end

    it "e-mails someone at PI with links to the files" do
      worker.perform

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.last

      expect(mail.body.raw_source.include?(report_url)).to be true
      expect(mail.body.raw_source.include?(qc_url)).to be true
    end
  end

  def delete_report_files
    filepaths = [qc_filepath, report_filepath, custom_report_filepath, custom_qc_filepath]
    FileUtils.rm_f(filepaths)
  end

  describe "ClientReportHistory" do
    let(:data_start_time) { 1.month.ago.beginning_of_month }

    context "when the report is successfully delivered" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:transfer_to_s3).and_return(FFaker::Internet.http_url)

        job_class.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        job_class = described_class.new
        # TODO: Find a less "white box" way to cause failure
        allow(job_class).to receive(:generate_submission_report).and_raise(StandardError)

        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end
end
