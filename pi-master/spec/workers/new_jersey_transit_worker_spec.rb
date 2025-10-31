# frozen_string_literal: true
require 'spec_helper'

describe NewJerseyTransitWorker do
  let(:worker) { described_class.new }

  it_behaves_like "delivery check" do
    let(:default_data_start_time) { 1.week.ago.beginning_of_week }
  end

  describe "Hubspot" do
    let(:contact_id) { rand(10 ** 8).to_s } # Random eight-digit integer
    let(:label) { "pulseinsights_rewardsvalue" }
    let(:question_id) { 19615 }

    let(:survey) { create(:survey_without_question) }
    let(:question) { create(:question_without_possible_answers, survey: survey, id: question_id) }
    let(:possible_answer) { create(:possible_answer, question: question) }
    let(:submission) { create(:submission, survey: survey, custom_data: {"contactid" => contact_id}) }

    context "when no answers from the last week are in the db" do
      before do
        create(:answer, question: question, submission: submission, possible_answer: possible_answer,
                        created_at: 8.days.ago)
      end

      it "does not call Hubspot" do
        expect(worker).not_to receive(:send_to_hubspot)

        worker.perform
      end
    end

    context "when an answer from the last week is in the db" do
      before do
        @answer = create(:answer, question: question, submission: submission, possible_answer: possible_answer,
                        created_at: 6.days.ago)
      end

      let(:inputs) do
        [{
          id: contact_id,
          properties: {
            label => possible_answer.content
          }
        }]
      end

      it "calls Hubspot with all required input" do
        expect(worker).to receive(:send_to_hubspot).with(inputs)

        worker.perform
      end

      context "when the answer is to a different question" do
        let(:question_id) { 18526 }
        let(:label) { "pulseinsights_travelchoice" }

        it "calls Hubspot with all required input" do
          expect(worker).to receive(:send_to_hubspot).with(inputs)

          worker.perform
        end
      end

      context "when there are duplicates" do
        it 'calls Hubspot with a unique set of the most recent inputs' do
          older_duplicate_answer = create(:answer, question: question, created_at: @answer.created_at - 30.minutes)
          older_duplicate_answer.submission.update(custom_data: {"contactid" => contact_id})

          expect(worker).to receive(:send_to_hubspot).with(inputs)

          worker.perform
        end
      end
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
        # TODO: Find a less "white box" way to cause failure
        allow(job_class).to receive(:send_confirmation_file_to_s3).and_raise(StandardError)
        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end
end
