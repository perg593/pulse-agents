# frozen_string_literal: true
require 'spec_helper'

describe TagAutomationWorker do
  context 'when tag_automation_job record does not exist' do
    let(:non_existent_tag_automation_id) { 0 }

    it 'does not raise any errors' do
      expect { described_class.new.perform(non_existent_tag_automation_id) }.not_to raise_error
    end
  end

  context 'when tag_automation_job record did not complete' do
    let(:tag_automation_job) { create(:tag_automation_job) }

    before do
      tag_automation_job.answers << create(:free_text_answer)

      allow(GPT).to receive(:chat).and_raise(StandardError)
    end

    it 'marks the record "failed"' do
      described_class.new.perform(tag_automation_job.id)
      expect(tag_automation_job.reload.failed?).to be true
    end
  end
end
