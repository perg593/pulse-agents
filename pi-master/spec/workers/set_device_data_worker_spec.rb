# frozen_string_literal: true
require 'spec_helper'

describe SetDeviceDataWorker do
  before do
    Sidekiq::Worker.clear_all
    Device.delete_all
    DeviceData.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'updates device_data with param' do
    account = create(:account)
    create(:device, udid: udid)

    described_class.new.perform(udid, 'identifier' => account.identifier, 'gender' => 'male')

    device_data = DeviceData.last
    expect(device_data.device_data).to eq('gender' => 'male')
  end

  it 'merges new device_data with existing one' do
    account = create(:account)
    create(:device, udid: udid)

    described_class.new.perform(udid, 'identifier' => account.identifier, 'gender' => 'male')
    described_class.new.perform(udid, 'identifier' => account.identifier, 'age' => '22')

    device_data = DeviceData.last
    expect(device_data.device_data).to eq('gender' => 'male', 'age' => '22')
  end
end
