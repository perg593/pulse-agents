# frozen_string_literal: true
require 'spec_helper'

RSpec.describe AIOutlineJob do
  describe 'associations' do
    it { is_expected.to belong_to(:survey) }
    it { is_expected.to belong_to(:prompt_template).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:survey) }
  end

  describe 'scopes' do
    let!(:pending_job) { create(:ai_outline_job, :pending) }
    let!(:generating_outline_job) { create(:ai_outline_job, :generating_outline) }
    let!(:outline_completed_job) { create(:ai_outline_job, :outline_completed) }
    let!(:generating_gamma_job) { create(:ai_outline_job, :generating_gamma) }
    let!(:completed_job) { create(:ai_outline_job, :completed) }
    let!(:failed_job) { create(:ai_outline_job, :failed) }

    it 'filters by status correctly' do
      expect(described_class.pending).to include(pending_job)
      expect(described_class.generating_outline).to include(generating_outline_job)
      expect(described_class.outline_completed).to include(outline_completed_job)
      expect(described_class.generating_gamma).to include(generating_gamma_job)
      expect(described_class.completed).to include(completed_job)
      expect(described_class.failed).to include(failed_job)
    end
  end

  describe '.create_for_survey' do
    let(:survey) { create(:survey) }
    let(:prompt_template) { create(:prompt_template) }

    it 'creates a job with default prompt' do
      job = described_class.create_for_survey(survey, use_default_prompt: true)

      expect(job.survey).to eq(survey)
      expect(job.use_default_prompt).to be true
      expect(job.status).to eq('pending')
    end

    it 'creates a job with prompt template' do
      job = described_class.create_for_survey(survey, prompt_template: prompt_template)

      expect(job.survey).to eq(survey)
      expect(job.prompt_template).to eq(prompt_template)
      expect(job.status).to eq('pending')
    end

    it 'creates a job with custom prompt text' do
      job = described_class.create_for_survey(survey, prompt_text: 'Custom prompt')

      expect(job.survey).to eq(survey)
      expect(job.prompt_text).to eq('Custom prompt')
      expect(job.status).to eq('pending')
    end
  end

  describe 'status transitions' do
    let(:job) { create(:ai_outline_job, :pending) }

    it 'transitions to generating_outline' do
      job.start_processing!

      expect(job.status).to eq('generating_outline')
      expect(job.started_at).to be_present
    end

    it 'completes outline successfully' do
      outline_content = "# Test Outline\n\n## Summary\nTest content"
      job.complete_outline!(outline_content)

      expect(job.status).to eq('outline_completed')
      expect(job.outline_content).to eq(outline_content)
      expect(job.completed_at).to be_present
    end

    it 'fails with error message' do
      error_message = 'Something went wrong'
      job.fail!(error_message)

      expect(job.status).to eq('failed')
      expect(job.error_message).to eq(error_message)
      expect(job.completed_at).to be_present
    end
  end

  describe 'status checks' do
    it 'identifies processing jobs' do
      pending_job = create(:ai_outline_job, :pending)
      generating_outline_job = create(:ai_outline_job, :generating_outline)
      outline_completed_job = create(:ai_outline_job, :outline_completed)
      generating_gamma_job = create(:ai_outline_job, :generating_gamma)
      completed_job = create(:ai_outline_job, :completed)
      failed_job = create(:ai_outline_job, :failed)

      expect(pending_job.processing?).to be true
      expect(generating_outline_job.processing?).to be true
      expect(outline_completed_job.processing?).to be true
      expect(generating_gamma_job.processing?).to be true
      expect(completed_job.processing?).to be false
      expect(failed_job.processing?).to be false
    end

    it 'identifies completed jobs' do
      pending_job = create(:ai_outline_job, :pending)
      generating_outline_job = create(:ai_outline_job, :generating_outline)
      outline_completed_job = create(:ai_outline_job, :outline_completed)
      generating_gamma_job = create(:ai_outline_job, :generating_gamma)
      completed_job = create(:ai_outline_job, :completed)
      failed_job = create(:ai_outline_job, :failed)

      expect(pending_job.job_completed?).to be false
      expect(generating_outline_job.job_completed?).to be false
      expect(outline_completed_job.job_completed?).to be false
      expect(generating_gamma_job.job_completed?).to be false
      expect(completed_job.job_completed?).to be true
      expect(failed_job.job_completed?).to be false
    end

    it 'identifies finished jobs' do
      pending_job = create(:ai_outline_job, :pending)
      generating_outline_job = create(:ai_outline_job, :generating_outline)
      outline_completed_job = create(:ai_outline_job, :outline_completed)
      generating_gamma_job = create(:ai_outline_job, :generating_gamma)
      completed_job = create(:ai_outline_job, :completed)
      failed_job = create(:ai_outline_job, :failed)

      expect(pending_job.job_finished?).to be false
      expect(generating_outline_job.job_finished?).to be false
      expect(outline_completed_job.job_finished?).to be false
      expect(generating_gamma_job.job_finished?).to be false
      expect(completed_job.job_finished?).to be true
      expect(failed_job.job_finished?).to be true
    end

    it 'identifies outline generation completion states' do
      pending_job = create(:ai_outline_job, :pending)
      generating_outline_job = create(:ai_outline_job, :generating_outline)
      outline_completed_job = create(:ai_outline_job, :outline_completed)
      generating_gamma_job = create(:ai_outline_job, :generating_gamma)
      completed_job = create(:ai_outline_job, :completed)
      failed_job = create(:ai_outline_job, :failed)

      expect(pending_job.outline_generation_completed?).to be false
      expect(generating_outline_job.outline_generation_completed?).to be false
      expect(outline_completed_job.outline_generation_completed?).to be true
      expect(generating_gamma_job.outline_generation_completed?).to be true
      expect(completed_job.outline_generation_completed?).to be true
      expect(failed_job.outline_generation_completed?).to be false

      expect(pending_job.outline_generation_finished?).to be false
      expect(generating_outline_job.outline_generation_finished?).to be false
      expect(outline_completed_job.outline_generation_finished?).to be true
      expect(generating_gamma_job.outline_generation_finished?).to be true
      expect(completed_job.outline_generation_finished?).to be true
      expect(failed_job.outline_generation_finished?).to be true
    end

    it 'tracks errors properly' do
      failed_job = create(:ai_outline_job, :failed, error_message: 'Test error')

      expect(failed_job.errors?).to be true
      expect(failed_job.error_summary).to include(
        status: 'failed',
        error_message: 'Test error',
        failed_at: failed_job.completed_at
      )
    end

    it 'returns nil error summary for jobs without errors' do
      completed_job = create(:ai_outline_job, :completed)
      failed_job_no_error = create(:ai_outline_job, :failed, error_message: nil)

      expect(completed_job.errors?).to be false
      expect(completed_job.error_summary).to be_nil
      expect(failed_job_no_error.errors?).to be false
      expect(failed_job_no_error.error_summary).to be_nil
    end
  end
end
