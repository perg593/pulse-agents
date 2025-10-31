# frozen_string_literal: true
require 'spec_helper'

describe AISummarizationWorker do
  describe "non-pending record handling" do
    let(:question) { create(:free_text_question) }
    let(:ai_summarization_job) { create(:ai_summarization_job, question: question, status: status) }

    [:in_progress, :done].each do |non_pending_status|
      context "when the record is '#{non_pending_status}'" do
        let(:status) { non_pending_status }

        it "does not call the summarizer" do
          expect(AISummarization).not_to receive(:summarize)
          described_class.new.perform(ai_summarization_job.id)
        end
      end
    end
  end

  describe "changes to ai_summarization_job" do
    let(:question) { create(:free_text_question) }
    let(:ai_summarization_job) { create(:ai_summarization_job, question: question) }
    let(:stubbed_summary) { "placeholder_summary" }

    before do
      allow(AISummarization).to receive(:summarize).and_return(stubbed_summary)

      described_class.new.perform(ai_summarization_job.id)
      ai_summarization_job.reload
    end

    it "sets the record to in_progress" do
      expect(ai_summarization_job.audits.changes_attribute_to(:status, AISummarizationJob.statuses[:in_progress])).to exist
    end

    it "sets the record to done" do
      expect(ai_summarization_job.done?).to be true
    end

    it "stores summaries in ai_summarization_job" do
      expect(ai_summarization_job.summary).to eq stubbed_summary
    end
  end

  describe "answer scope" do
    let(:question) { create(:free_text_question) }
    let(:ai_summarization_job) { create(:ai_summarization_job, question: question) }

    before do
      2.times { create(:answer, question: question, text_answer: FFaker::Lorem.phrase) }
      question.reload
    end

    it "calls AISummarization with ai_summarization_job's question's answers" do
      expect(AISummarization).to receive(:summarize).with(match_array(question.answers), strategy: AISummarization::STRATEGY_LAST_RESPONSES)
      described_class.new.perform(ai_summarization_job.id)
    end
  end
end
