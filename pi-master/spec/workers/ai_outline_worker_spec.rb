# frozen_string_literal: true
require 'spec_helper'

describe AIOutlineWorker do
  describe "completed record handling" do
    let(:survey) { create(:survey) }
    let(:ai_outline_job) { create(:ai_outline_job, survey: survey, status: status) }

    [:outline_completed, :generating_gamma, :completed, :failed].each do |completed_status|
      context "when the record is '#{completed_status}'" do
        let(:status) { completed_status }

        it "does not call the AI outline generator for completed jobs" do
          expect(AIOutlineGeneration).not_to receive(:generate_outline)
          described_class.new.perform(ai_outline_job.id)
        end
      end
    end
  end

  describe "successful outline generation" do
    let(:survey) { create(:survey) }
    let(:ai_outline_job) { create(:ai_outline_job, survey: survey) }
    let(:stubbed_outline) { "# Survey Analysis Report\n\n## Executive Summary\nMock outline content for testing." }

    before do
      allow(AIOutlineGeneration).to receive(:generate_outline).with(ai_outline_job).and_return(stubbed_outline)

      described_class.new.perform(ai_outline_job.id)
      ai_outline_job.reload
    end

    it "sets the record to generating_outline" do
      expect(ai_outline_job.audits.changes_attribute_to(:status, AIOutlineJob.statuses[:generating_outline])).to exist
    end

    it "sets the record to outline_completed" do
      expect(ai_outline_job.outline_completed?).to be true
    end

    it "stores outline content in ai_outline_job" do
      expect(ai_outline_job.outline_content).to eq stubbed_outline
    end
  end

  describe "failed outline generation" do
    let(:survey) { create(:survey) }
    let(:ai_outline_job) { create(:ai_outline_job, survey: survey) }
    let(:error_message) { "AI generation failed" }

    before do
      allow(AIOutlineGeneration).to receive(:generate_outline).and_raise(StandardError, error_message)
    end

    it "marks the job as failed with error message" do
      expect { described_class.new.perform(ai_outline_job.id) }.to raise_error(StandardError, error_message)

      ai_outline_job.reload
      expect(ai_outline_job.failed?).to be true
      expect(ai_outline_job.error_message).to eq error_message
    end
  end

  describe "job state transitions" do
    let(:survey) { create(:survey) }
    let(:ai_outline_job) { create(:ai_outline_job, survey: survey) }
    let(:stubbed_outline) { "Mock outline content" }

    before do
      allow(AIOutlineGeneration).to receive(:generate_outline).and_return(stubbed_outline)
    end

    it "transitions from pending to generating_outline to outline_completed" do
      expect(ai_outline_job.pending?).to be true

      described_class.new.perform(ai_outline_job.id)
      ai_outline_job.reload

      expect(ai_outline_job.outline_completed?).to be true
      expect(ai_outline_job.started_at).to be_present
      expect(ai_outline_job.completed_at).to be_present
    end
  end
end
