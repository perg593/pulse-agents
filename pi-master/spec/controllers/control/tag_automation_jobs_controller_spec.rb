# frozen_string_literal: true
require 'spec_helper'

describe Control::TagAutomationJobsController do
  describe 'GET #poll' do
    let(:account) { create(:account) }
    let(:question) { create(:question, survey: create(:survey, account: account)) }

    before do
      sign_in create(:user, account: account)
    end

    context 'when tag_automation_job belongs to a different account' do
      let(:tag_automation_job) { create(:tag_automation_job) }

      before do
        # rubocop:disable Rspec/AnyInstance - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        get :poll, params: { id: tag_automation_job.id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when tag_automation_job has not completed yet' do
      let(:tag_automation_job) { create(:tag_automation_job, question: question, status: :in_progress) }

      it 'returns the status of a tag_automation_job' do
        get :poll, params: { id: tag_automation_job.id }
        expect(JSON.parse(response.body)['status']).to eq tag_automation_job.status
      end
    end

    context 'when tag_automation_job has completed' do
      let(:answer) { create(:answer, question: question) }
      let(:tag) { create(:tag, question: question) }
      let(:tag_automation_job) { create(:tag_automation_job, question: question, status: :completed) }
      let!(:applied_tag) { create(:applied_tag, answer: answer, tag: tag, tag_automation_job: tag_automation_job) }

      it 'returns the status and generated applied_tags' do
        get :poll, params: { id: tag_automation_job.id }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['status']).to eq tag_automation_job.status
        expect(parsed_response['appliedTags'].first['name']).to eq tag.name
        expect(parsed_response['appliedTags'].first['color']).to eq tag.color
        expect(parsed_response['appliedTags'].first['answerId']).to eq answer.id
        expect(parsed_response['appliedTags'].first['appliedTagId']).to eq applied_tag.id
        expect(parsed_response['appliedTags'].first['id']).to eq tag.id
      end
    end
  end
end
