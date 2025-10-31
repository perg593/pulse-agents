# frozen_string_literal: true
require 'spec_helper'

describe Azurity::AzurityWorker do
  def azurity_account_ids
    [
      382, # Horizant
      378, # Adthyza_HCP
      379, # Adthyza_Consumer
      366, # Triptodur
      381, # Eprontia
      383, # Zonisade
      384, # EFamily
      375, # Katerzia
      376, # Qbrelis
      377, # Nymalize
      410, # "Konvomep"
      402, # "First Kits"
      403, # "Vivimusta"
      419, # "Myhibbin"
      425, # "Xatmep"
      424 # "Azmiro"
    ]
  end

  before do
    azurity_account_ids.each do |account_id|
      account = create(:account, id: account_id)
      survey = create(:survey, account: account)

      create_sample_answer(survey)
    end

    # Clean up any existing CSV files before each test
    FileUtils.rm_f(Dir.glob("tmp/PulseInsights*.csv"))
  end

  after do
    # Clean up any CSV files after each test
    FileUtils.rm_f(Dir.glob("tmp/PulseInsights*.csv"))
  end

  def create_sample_answer(survey)
    submission = create(:submission, survey: survey)
    create(:answer, submission: submission, question: survey.questions.first,
           possible_answer: survey.questions.first.possible_answers.first)
  end

  describe "report" do
    let(:horizant_filename) { "PulseInsights_Horizant_#{timestamp}.csv" }
    let(:adthyza_hcp_filename) { "PulseInsights_Adthyza_HCP_#{timestamp}.csv" }
    let(:collated_filename) { "PulseInsights_All_Brands_#{timestamp}.csv" }

    let(:timestamp) { Time.current.strftime("%d%m%y") }

    def load_rows(filename)
      CSV.parse(File.read("tmp/#{filename}"), headers: false)
    end

    it "generates individual brand CSV files and collates them" do
      described_class.new.perform(start_date: 1.day.ago, end_date: 1.day.from_now)

      # Check that individual brand files are generated
      expect(File.exist?("tmp/#{horizant_filename}")).to be true
      expect(File.exist?("tmp/#{adthyza_hcp_filename}")).to be true

      # Check that collated file is generated
      expect(File.exist?("tmp/#{collated_filename}")).to be true

      # Verify individual files have different data
      horizant_rows = load_rows(horizant_filename)
      adthyza_hcp_rows = load_rows(adthyza_hcp_filename)
      expect(horizant_rows).not_to match_array adthyza_hcp_rows

      # Verify collated file contains data from both brands
      collated_rows = load_rows(collated_filename)
      expect(collated_rows.length).to be > 1 # Should have headers + data rows

      # Check that collated file has Brand Name column
      headers = collated_rows.first
      expect(headers).to include('Brand Name')
    end

    context "when a free text answer contains newlines" do
      before do
        # Create a survey with a free text question that has newlines in the response
        account = Account.find(382) # Horizant
        survey = account.surveys.first

        # Create a free text question
        question = create(:free_text_question, survey: survey)

        # Create a submission with newlines in the response
        submission = create(:submission, survey: survey)

        # Create an answer with newlines in the response
        create(:answer, submission: submission, question: question, text_answer: "This response\nhas a newline")
      end

      it "properly handles newlines within CSV fields during collation" do
        described_class.new.perform(start_date: 1.day.ago, end_date: 1.day.from_now)

        # Verify the collated file exists
        expect(File.exist?("tmp/#{collated_filename}")).to be true

        # Parse the collated file and verify newlines are preserved
        collated_rows = load_rows(collated_filename)

        # Should have headers + data rows
        expect(collated_rows.length).to be > 1

        # Check that newlines are preserved in the data
        data_rows = collated_rows[1..] # Skip header
        expect(data_rows.any? { |row| row.any? { |cell| cell&.include?("\n") } }).to be true
      end
    end

    context "when an account has no surveys" do
      before do
        Account.find(382).surveys.destroy_all # HORIZANT
      end

      it "processes subsequent accounts and still generates collated file" do
        described_class.new.perform

        # Should still generate collated file even with one account having no surveys
        expect(File.exist?("tmp/#{collated_filename}")).to be true

        # Should still have data from other accounts
        adthyza_hcp_rows = load_rows(adthyza_hcp_filename)
        expect(adthyza_hcp_rows).not_to be_nil
      end
    end

    context "when no accounts have surveys" do
      before do
        Account.all.each { |account| account.surveys.destroy_all }
      end

      it "does not generate collated file when no individual files are available" do
        described_class.new.perform

        expect(File.exist?("tmp/#{collated_filename}")).to be false
      end
    end

    describe "ClientReportHistory" do
      let(:data_start_time) { 1.week.ago.beginning_of_day }

      context "when the report is successfully delivered" do
        before do
          described_class.new.perform
        end

        include_examples "status logger logs success"
      end

      context "when the report fails" do
        before do
          job_class = described_class.new
          allow(job_class).to receive(:upload_collated_file_to_azurity).and_raise(StandardError)

          job_class.perform
        end

        include_examples "status logger logs failure"
      end
    end
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.week.ago.beginning_of_week }
  end
end
