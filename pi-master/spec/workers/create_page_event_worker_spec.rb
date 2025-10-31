# frozen_string_literal: true

require 'spec_helper'

describe CreatePageEventWorker do
  before do
    Sidekiq::Worker.clear_all
  end

  let(:account) { create(:account) }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  # Commenting out until they pass consistently in CI. One of these two tickets can resolve it:
  # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1365
  # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  #
  # it 'creates a PageEvent' do
  #   event_name = 'test_event'
  #   event_properties = { test: 1 }.to_json
  #   url = 'https://test.com'
  #
  #   expect(PageEvent.count).to eq 0
  #   described_class.new.perform(event_name, event_properties, account.identifier, device.udid, url)
  #   expect(PageEvent.count).to eq 1
  #
  #   page_event = PageEvent.first
  #   expect(page_event.name).to eq event_name
  #   expect(page_event.properties).to eq event_properties
  #   expect(page_event.account).to eq account
  #   expect(page_event.device).to eq device
  #   expect(page_event.url).to eq url
  # end
  #
  # it 'bails early if account was not found' do
  #   expect(PageEvent.count).to eq 0
  #   described_class.new.perform('test_event', { test: 1 }.to_json, 'PI-11111111', udid, 'https://test.com')
  #   expect(PageEvent.count).to eq 0
  # end
  #
  # it 'creates a device if not found' do
  #   described_class.new.perform('test_event', { test: 1 }.to_json, account.identifier, udid, 'https://test.com')
  #   expect(PageEvent.first.device.udid).to eq udid
  # end
end
