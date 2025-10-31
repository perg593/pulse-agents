# frozen_string_literal: true
require 'spec_helper'

describe AISummarizationJob do
  let(:question) { create(:free_text_question) }

  describe "validations" do
    subject { ai_summarization_job.valid? }

    let(:ai_summarization_job) { described_class.new(question_id: question.id) }

    describe "question" do
      context "when the question is not a free text question" do
        let(:question) { create(:single_choice_question) }

        it { is_expected.to be false }
      end
    end

    describe "status" do
      context "when a job changes from pending to in_progress" do
        let(:ai_summarization_job) { create(:ai_summarization_job, status: :pending, question: create(:free_text_question)) }

        before do
          ai_summarization_job.status = :in_progress
        end

        it { is_expected.to be true }
      end

      context "when there is an unfinished AISummarizationJob record for a different question" do
        let(:status) { :pending }

        before do
          create(:ai_summarization_job, status: status, question: create(:free_text_question))
        end

        it { is_expected.to be true }
      end

      context "when the question is the same" do
        before do
          create(:ai_summarization_job, status: status, question_id: question.id)
        end

        context "when there is an unfinished AISummarizationJob record" do
          context "when the record is pending" do
            let(:status) { :pending }

            it { is_expected.to be false }
          end

          context "when the record is in_progress" do
            let(:status) { :in_progress }

            it { is_expected.to be false }
          end
        end

        context "when there are no unfinished AISummarizationJobs records" do
          let(:status) { :done }

          it { is_expected.to be true }
        end
      end
    end
  end
end
