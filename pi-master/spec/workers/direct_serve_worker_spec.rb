# frozen_string_literal: true

require 'spec_helper'

describe DirectServeWorker do
  before do
    Submission.delete_all
    Device.delete_all
  end

  after do
    Submission.delete_all
    Device.delete_all
  end

  let(:survey) { create(:survey) }
  let(:submission_udid) { SecureRandom.uuid }
  let(:device_udid) { SecureRandom.uuid }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'creates an impression' do
    expect do
      described_class.new.perform(survey.id, submission_udid, nil, device_udid, nil, nil)
    end.to change { Submission.count }.by 1
  end

  context 'when a device is not provided' do
    it 'creates a device' do
      expect do
        described_class.new.perform(survey.id, submission_udid, nil, device_udid, nil, nil)
      end.to change { Device.count }.by 1
    end
  end

  context 'when a device is provided' do
    context 'when a client key is provided' do
      it 'updates the device with the client key' do
        device = create(:device, udid: device_udid)
        client_key = FFaker::Lorem.word

        expect(device.client_key).not_to eq client_key
        survey.account # Prevent Qrvey::UserWorker from running inline

        Sidekiq::Testing.inline! do # This worker enqueues another worker that updates "devices"."client_key"
          described_class.new.perform(survey.id, submission_udid, device.id, device_udid, nil, client_key)
        end
        expect(device.reload.client_key).to eq client_key
      end
    end
  end
end
