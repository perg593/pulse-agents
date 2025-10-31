# frozen_string_literal: true

require 'spec_helper'

describe Control::PageEventsController do
  describe "DELETE #delete_all" do
    it "is not available to reporting level users" do
      account = create(:account)
      sign_in create(:reporting_only_user, account: account)

      page_event = create(:page_event, name: 'test', account: account)

      delete :delete_all, params: { event_name: page_event.name }

      expect_redirected_to_dashboard
    end

    it 'deletes all events with the specified name' do
      account = create(:account)
      10.times do
        create(:page_event, name: 'test1', account: account)
        create(:page_event, name: 'test2', account: account)
      end

      sign_in create(:user, account: account)
      delete :delete_all, params: { event_name: 'test2' }
      expect(account.page_events.where(name: 'test1').count).to eq 10
      expect(account.page_events.where(name: 'test2').count).to eq 0
    end

    it 'does not delete events that belong to other account' do
      account1 = create(:account)
      account2 = create(:account)
      10.times do
        create(:page_event, name: 'test', account: account1)
        create(:page_event, name: 'test', account: account2)
      end

      sign_in create(:user, account: account2)
      delete :delete_all, params: { event_name: 'test' }
      expect(account1.page_events.where(name: 'test').count).to eq 10
      expect(account2.page_events.where(name: 'test').count).to eq 0
    end
  end
end
