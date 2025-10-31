# frozen_string_literal: true
require 'spec_helper'

describe Crocs::CrocsWorker do
  def crocs_account_ids
    [
      433, # Crocs
      435  # HeyDude
    ]
  end

  before do
    crocs_account_ids.each do |account_id|
      account = create(:account, id: account_id)
      survey = create(:survey, account: account)

      create_sample_answer(survey)
    end

    # Clean up any existing CSV files before each test
    FileUtils.rm_f(Dir.glob("tmp/PulseInsights*.csv"))
    FileUtils.rm_f(Dir.glob("tmp/pulse-survey-data_crocs-heydude*.csv"))
  end

  after do
    # Clean up any CSV files after each test
    FileUtils.rm_f(Dir.glob("tmp/PulseInsights*.csv"))
    FileUtils.rm_f(Dir.glob("tmp/pulse-survey-data_crocs-heydude*.csv"))
  end

  def create_sample_answer(survey)
    submission = create(:submission, survey: survey)
    create(:answer, submission: submission, question: survey.questions.first,
           possible_answer: survey.questions.first.possible_answers.first)
  end

  describe "report" do
    let(:crocs_filename) { "PulseInsights_Crocs_#{timestamp}.csv" }
    let(:heydude_filename) { "PulseInsights_HeyDude_#{timestamp}.csv" }
    let(:collated_filename) { "pulse-survey-data_crocs-heydude_#{timestamp}.csv" }

    let(:timestamp) { Time.current.strftime("%Y-%m-%d") }

    def load_rows(filename)
      CSV.read("tmp/#{filename}")
    end

    it "generates individual brand CSV files and collates them" do
      described_class.new.perform(start_date: 1.day.ago, end_date: 1.day.from_now)

      # Check that individual brand files are generated
      expect(File.exist?("tmp/#{crocs_filename}")).to be true
      expect(File.exist?("tmp/#{heydude_filename}")).to be true

      # Check that collated file is generated
      expect(File.exist?("tmp/#{collated_filename}")).to be true

      # Verify individual files have different data
      crocs_rows = load_rows(crocs_filename)
      heydude_rows = load_rows(heydude_filename)
      expect(crocs_rows).not_to match_array heydude_rows

      # Verify collated file contains data from both brands
      collated_rows = load_rows(collated_filename)

      collated_crocs_rows = crocs_rows.map { |row| row + ["Crocs"] }
      collated_heydude_rows = heydude_rows.map { |row| row + ["HeyDude"] }

      expect(collated_rows[1..]).to include(*collated_crocs_rows[1..])
      expect(collated_rows[1..]).to include(*collated_heydude_rows[1..])

      # Check that collated file has Brand Name column
      headers = collated_rows.first
      expect(headers).to include('Brand Name')
    end

    context "when a free text answer contains newlines" do
      before do
        # Create a survey with a free text question that has newlines in the response
        account = Account.find(433) # Crocs
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
        Account.find(433).surveys.destroy_all # Crocs
      end

      it "processes subsequent accounts and still generates collated file" do
        described_class.new.perform

        # Should still generate collated file even with one account having no surveys
        expect(File.exist?("tmp/#{collated_filename}")).to be true

        # Should still have data from other accounts
        heydude_rows = load_rows(heydude_filename)
        expect(heydude_rows).not_to be_nil
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

    context "with dry_run parameter" do
      it "does not upload files when dry_run is true" do
        worker = described_class.new
        expect(worker).not_to receive(:upload_collated_file)

        worker.perform(dry_run: true)
      end

      it "uploads files when dry_run is false" do
        worker = described_class.new
        expect(worker).to receive(:upload_collated_file).and_call_original

        worker.perform(dry_run: false)
      end
    end

    context "with historical parameter" do
      it "generates historical filenames when historical is true" do
        described_class.new.perform(historical: true)

        expect(File.exist?("tmp/PulseInsights_Crocs_historical.csv")).to be true
        expect(File.exist?("tmp/PulseInsights_HeyDude_historical.csv")).to be true
        expect(File.exist?("tmp/pulse-survey-data_crocs-heydude_historical.csv")).to be true
      end

      it "generates date-based filenames when historical is false" do
        described_class.new.perform(historical: false)

        expect(File.exist?("tmp/#{crocs_filename}")).to be true
        expect(File.exist?("tmp/#{heydude_filename}")).to be true
        expect(File.exist?("tmp/#{collated_filename}")).to be true
      end
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
          allow(job_class).to receive(:upload_collated_file_to_crocs).and_raise(StandardError)

          job_class.perform
        end

        include_examples "status logger logs failure"
      end
    end
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.day.ago.beginning_of_day }
  end
end
