# frozen_string_literal: true
require 'spec_helper'

describe TagAutomationJob do
  describe '#auto_tag' do
    let(:question) { create(:free_text_question) }
    let(:answer) { create(:free_text_answer, question: question) }
    let(:tag) { create(:tag, question: question) }
    let(:tag_automation_job) { create(:tag_automation_job, question: question) }

    before do
      tag_automation_job.answers << answer

      allow(tag_automation_job).to receive(:request_auto_tag).and_return(gpt_response)
    end

    context 'when a tag was not found' do
      let(:gpt_response) { [{ 'tag' => FFaker::Lorem.word, 'answer_id' => answer.id }] }

      it 'tags with a placeholder tag' do
        tag_automation_job.auto_tag

        applied_tag = tag_automation_job.reload.applied_tags.first
        expect(applied_tag.tag.name).to eq Tag::AUTOMATION_PLACEHOLDER_NAME
      end
    end

    context 'when an answer was not found' do
      let(:gpt_response) { [{ 'tag' => tag.name, 'answer_id' => rand }] }

      it 'holds off tagging' do
        tag_automation_job.auto_tag

        expect(tag_automation_job.reload.applied_tags.exists?).to be false
      end
    end

    context 'when both tag and answer were found' do
      let(:gpt_response) { [{ 'tag' => tag.name, 'answer_id' => answer.id }] }

      it 'creates applied_tag records with pending approval' do
        tag_automation_job.auto_tag

        applied_tag = tag_automation_job.reload.applied_tags.first
        expect(applied_tag.tag_id).to eq tag.id
        expect(applied_tag.answer_id).to eq answer.id
        expect(applied_tag.is_good_automation).to be false
      end
    end
  end
end
