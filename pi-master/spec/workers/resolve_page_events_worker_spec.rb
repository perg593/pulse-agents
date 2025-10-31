# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/EmptyExampleGroup
describe ResolvePageEventsWorker do
  let(:event_name) { 'test_event' }
  let(:event_properties) { { test: 1 }.to_json }
  let(:account) { create(:account) }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }
  let(:automation) { create(:automation_with_condition_and_action, condition_type: :url, action_type: :create_event, account: account) }

  let(:url_matcher) { :url_is }
  let(:condition) { 'https://test.com' }

  before do
    automation.conditions.first.update(url_matcher: url_matcher, condition: condition)
    automation.actions.first.update(event_name: event_name, event_properties: event_properties)

    Sidekiq::Worker.clear_all
  end

  # TODO: Uncomment once it's working consistently in CI
  # it 'is retryable' do
  #   expect(described_class).to be_retryable true
  # end
  #
  # it 'bails early if account was not found' do
  #   expect { described_class.new.perform('PI-11111111', udid, 'https://test.com') }.not_to change { PageEvent.count }
  # end
  #
  # Problem might be related to https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  # it 'creates a device if not found' do
  #   described_class.new.perform(account.identifier, udid, 'https://test.com')
  #   expect(PageEvent.first.device.udid).to eq udid
  # end
  #
  # it 'does not create a PageEvent if an EventAutomaton is not enabled' do
  #   automation.update(enabled: false)
  #
  #   expect(PageEvent.count).to eq 0
  #   described_class.new.perform(account.identifier, udid, 'https://test.com')
  #   expect(PageEvent.count).to eq 0
  # end
  #
  # context 'when url matcher is "is"' do
  #   it "creates a PageEvent if a url is the same as an Automation's condition" do
  #     expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.to change { PageEvent.count }.from(0).to(1)
  #   end
  # end
  #
  # context 'when url matcher is "contains"' do
  #   let(:url_matcher) { :url_contains }
  #   let(:condition) { 'test' }
  #
  #   it "creates a PageEvent if a url contains an Automation's condition" do
  #     expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.to change { PageEvent.count }.from(0).to(1)
  #   end
  # end
  #
  # Problem might be related to https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  # context 'when url matcher is "matches"' do
  #   let(:url_matcher) { :url_matches }
  #   let(:condition) { 'https://test.*' }
  #
  #   it "creates a PageEvent if a url matches an Automation's condition" do
  #     expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.to change { PageEvent.count }.from(0).to(1)
  #   end
  # end
  #
  # describe "triggered_at & times_triggered" do
  #   context 'when a PageEvent object has been created' do
  #     it 'updates the stats' do
  #       expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.to change { automation.reload.last_triggered_at }
  #       expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.to change { automation.reload.times_triggered }.by(1)
  #     end
  #   end
  #
  #   context 'when a PageEvent object was not created due to an error' do
  #     it 'does not update the stats' do
  #       allow(PageEvent).to receive(:create!).and_raise('error')
  #       expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.not_to change { automation.reload.last_triggered_at }
  #       expect { described_class.new.perform(account.identifier, udid, 'https://test.com') }.not_to change { automation.reload.times_triggered }
  #     end
  #   end
  # end
end
