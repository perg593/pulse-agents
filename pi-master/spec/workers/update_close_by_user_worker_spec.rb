# frozen_string_literal: true
require 'spec_helper'

describe UpdateCloseByUserWorker do
  before do
    Sidekiq::Worker.clear_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'updates account calls and last call' do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.stop_showing_without_answer = true
    survey.save
    device = create(:device, udid: udid)
    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2)

    expect(submission.closed_by_user).to be false

    described_class.new.perform(submission.udid)

    expect(submission.reload.closed_by_user).to be true
  end
end
