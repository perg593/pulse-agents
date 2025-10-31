# frozen_string_literal: true
require 'spec_helper'

describe SaveCustomDataWorker do
  before do
    Sidekiq::Worker.clear_all
    Submission.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'updates custom data' do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.save
    device = create(:device, udid: udid)
    custom_data = { gender: 'male' }
    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0)

    expect(submission.custom_data).to be_nil

    described_class.new.perform(submission.udid, custom_data)

    expect(submission.reload.custom_data).not_to be_nil
    expect(submission.custom_data['gender']).to eq 'male'
  end
end
