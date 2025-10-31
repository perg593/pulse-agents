# frozen_string_literal: true
require 'spec_helper'

# rubocop:disable RSpec/SubjectStub
# We just want to know whether these API calls were made. We're not testing the calls themselves
describe MeleeWorker do
  describe 'Uploading output' do
    subject { worker }

    let(:worker) { described_class.new }

    let(:payload_filepath) do
      timestamp = Time.current.in_time_zone('America/New_York').strftime("%Y_%m_%d")
      "tmp/melee_#{timestamp}.json"
    end

    before do
      @account = create(:account, id: 191) # Comcast SpeedTest

      # rubocop:disable RSpec/VerifiedDoubleReference
      # We don't actually care about the class, we just want a 200 response code
      allow(RestClient::Request).to receive(:execute).and_return(instance_double("Res", code: 200))
      allow(worker).to receive_messages(send_melee_data: true, upload_copy_to_s3: true)
    end

    def create_data
      survey = create(:survey, account: @account)
      submission = create(:submission, survey: survey)
      # Results are calculated in Eastern time
      create(:answer, submission: submission, question: survey.questions.first, created_at: 50.minutes.ago.in_time_zone('America/New_York'))
    end

    context 'when it is the last run of the day' do
      before do
        travel_to Time.current.end_of_day - 50.minutes # run every hour
      end

      after do
        FileUtils.rm_f(payload_filepath)

        travel_back
      end

      context "with data" do
        before do
          create_data
          worker.perform
        end

        it { is_expected.to have_received(:send_melee_data).once }
        it { is_expected.to have_received(:upload_copy_to_s3).once }

        it 'creates a file to log a payload' do
          expect(File.exist?(payload_filepath)).to be true
        end
      end

      context "with no data" do
        before do
          worker.perform
        end

        it { is_expected.not_to have_received(:send_melee_data) }
        it { is_expected.to have_received(:upload_copy_to_s3).once }

        it 'creates a dummy file to bypass the checkup worker' do
          expect(File.exist?(payload_filepath)).to be true
        end
      end
    end

    context 'when it is not the last run of the day' do
      before do
        travel_to Time.current.beginning_of_day
      end

      after do
        FileUtils.rm_f(payload_filepath)

        travel_back
      end

      context "with data" do
        before do
          create_data
          worker.perform
        end

        it { is_expected.to have_received(:send_melee_data).once }
        it { is_expected.not_to have_received(:upload_copy_to_s3) }

        it 'creates a file to log a payload' do
          expect(File.exist?(payload_filepath)).to be true
        end
      end

      context "with no data" do
        before do
          worker.perform
        end

        it { is_expected.not_to have_received(:send_melee_data) }
        it { is_expected.not_to have_received(:upload_copy_to_s3) }

        it 'does not create a file to log a payload' do
          expect(File.exist?(payload_filepath)).to be false
        end
      end
    end
  end

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { Time.current.in_time_zone('America/New_York').beginning_of_hour - 1.hour }
  end

  describe "delivery checks" do
    subject { described_class.delivered_all_for_date?(1.day.ago.to_date) }

    before do
      create(:account, id: 191)
    end

    let(:job) do
      the_job = described_class.new
      allow(the_job).to receive(:send_answers).and_return(true)

      the_job
    end

    context "when there are exactly twenty-four runs recorded at the expected times" do
      before do
        (0..23).each do |i|
          data_start_time = 1.day.ago.to_date.in_time_zone('America/New_York').beginning_of_day + i.hours

          job.perform(start_time: data_start_time, end_time: data_start_time + 1.hour)
        end
      end

      it { is_expected.to be true }
    end

    context "when there are exactly twenty-four runs, but recorded at unexpected times" do
      before do
        24.times { job.perform }
      end

      it { is_expected.to be false }
    end

    context "when there are less than four runs recorded for the day" do
      before do
        3.times { job.perform }
      end

      it { is_expected.to be false }
    end

    context "when there are more than four runs recorded for the day" do
      before do
        5.times { job.perform }
      end

      it { is_expected.to be false }
    end
  end

  describe "ClientReportHistory" do
    let(:data_start_time) { Time.current.in_time_zone('America/New_York') - 1.hour }

    before do
      freeze_time
    end

    after do
      unfreeze_time
    end

    context "when the report is successfully delivered" do
      before do
        create(:account, id: 191)
        described_class.new.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        described_class.new.perform
      end

      include_examples "status logger logs failure"
    end
  end
end
