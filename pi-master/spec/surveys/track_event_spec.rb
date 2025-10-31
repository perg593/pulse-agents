# frozen_string_literal: true

require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Track Event' do
  let(:account) { create(:account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  it 'creates a PageEvent record' do
    event_name = 'test event'
    event_properties = { test: 1, event: 2 }.to_json

    expect(PageEvent.count).to eq 0
    driver.execute_script("pi('track_event', '#{event_name}', { test: 1, event: 2})")
    sleep 1 # wait for Rack app & Sidekiq worker
    expect(PageEvent.count).to eq 1

    page_event = PageEvent.first
    expect(page_event.name).to eq event_name
    expect(page_event.properties).to eq event_properties
  end
end
