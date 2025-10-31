# frozen_string_literal: true
require 'spec_helper'

describe CreateDeviceWorker do
  before do
    Sidekiq::Worker.clear_all
    Device.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'finds or create a device with the given udid' do
    described_class.new.perform(udid)
    expect(Device.first).not_to be_nil
    expect(Device.first.udid).to eq(udid)

    described_class.new.perform(udid)
    expect(Device.count).to eq(1)
  end

  it 'identifies a capped udid is valid' do
    capped_udid = udid.upcase
    described_class.new.perform(capped_udid)
    expect(Device.first).not_to be_nil
    expect(Device.first.udid).to eq(capped_udid)

    described_class.new.perform(capped_udid)
    expect(Device.count).to eq(1)
  end

  it 'returns empty hash if udid is not valid' do
    res = described_class.new.perform('c054eeeb-3e3f-4e01-a063-%%%%%%%%%%%%')
    expect(Device.first).to be_nil
    # rubocop:disable Lint/EmptyBlock
    expect(res).to be {}
  end
end
