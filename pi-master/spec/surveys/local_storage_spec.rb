# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

# There's a problem with our use of the rails server that makes these fail and
# take 20mins to process. These probably won't be ready for CI until we find a
# better way of accessing the rack server.
describe 'Local Storage' do
  let(:account) { create(:account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:pi_keys) { %w(pi_pageview_count pi_visit_track pi_visit_count pulse_insights_udid pulse_insights_client_key) }

  context 'when loaded' do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')
        before_tag_load.manage.add_cookie(name: 'pi_visit_track', value: 'false')
        before_tag_load.manage.add_cookie(name: 'pi_visit_count', value: '1')
        before_tag_load.manage.add_cookie(name: 'pi_pageview_count', value: '1')
      end
    end

    it 'migrates items from Cookies to Local Storage' do
      log_messages = driver.execute_script('return window.PulseInsightsObject.logMessages;').join(', ')

      # migrate from Cookies to Local Storage
      expect(log_messages).to include('Cookie was migrated to Local Storage pi_visit_track: false')
      expect(log_messages).to include('Cookie was migrated to Local Storage pi_visit_count: 1')
      expect(log_messages).to include('Cookie was migrated to Local Storage pi_pageview_count: 1')

      # proceed to update items in Local Storage
      expect(log_messages).to include('Set item in Local Storage pi_visit_track:') # can't predict a timestamp made by Javascript
      expect(log_messages).to include('Set item in Local Storage pi_visit_count: 2')
      expect(log_messages).to include('Set item in Local Storage pi_pageview_count: 2')
    end
  end

  context 'when pi_visit_track is older than 20 mins' do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')

        before_tag_load.execute_script("window.localStorage.setItem('pi_visit_track', #{yesterday_epoch});")
        before_tag_load.execute_script("window.localStorage.setItem('pi_visit_count', '1');")
        before_tag_load.execute_script("window.localStorage.setItem('pi_pageview_count', '2');")
      end
    end
    let(:yesterday_epoch) { Time.now.yesterday.to_i * 1000 } # epoch time is milliseconds in Javascript

    it 'increments visit, resets pageview and sets pi_visit_track' do
      log_messages = driver.execute_script('return window.PulseInsightsObject.logMessages;').join(', ')

      expect(log_messages).to include('Set item in Local Storage pi_visit_count: 2')    # increment visit
      expect(log_messages).to include('Set item in Local Storage pi_pageview_count: 1') # reset pageview
      expect(log_messages).to include('Set item in Local Storage pi_visit_track:')      # update timestamp
    end
  end

  context 'when pi_visit_track is younger than 20 mins' do
    let(:current_epoch) { Time.now.to_i * 1000 } # epoch time is milliseconds in Javascript
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')

        before_tag_load.execute_script("window.localStorage.setItem('pi_visit_track', #{current_epoch});")
        before_tag_load.execute_script("window.localStorage.setItem('pi_visit_count', '1');")
        before_tag_load.execute_script("window.localStorage.setItem('pi_pageview_count', '1');")
      end
    end

    it 'increments pageview and sets pi_visit_track' do
      log_messages = driver.execute_script('return window.PulseInsightsObject.logMessages;').join(', ')

      expect(log_messages).to include('Set item in Local Storage pi_pageview_count: 2') # increment pageview
      expect(log_messages).to include('Set item in Local Storage pi_visit_track:')      # update timestamp
    end
  end

  context 'when visitor_tracking is never called' do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')
      end
    end

    before do
      driver.execute_script("pi('identify_client', 'TK-421');")
    end

    it 'PI data is put in Local Storage' do
      it_stores_all_pi_data_in_local_storage
    end
  end

  context 'when visitor_tracking is set to true' do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')
      end
    end

    before do
      driver.execute_script("pi('visitor_tracking', true);")
      driver.execute_script("pi('identify_client', 'TK-421');")
    end

    it 'PI data is put in Local Storage' do
      it_stores_all_pi_data_in_local_storage
    end

    context "when refresh" do
      before do
        driver.execute_script(<<~JS)
          window.PulseInsightsObject = new window.PulseInsights();
        JS
      end

      it 'persists' do
        visitor_tracking = find_in_local_storage("pi_visitor_tracking")
        expect(visitor_tracking).to eq(true.to_s)

        it_stores_all_pi_data_in_local_storage
      end
    end
  end

  context 'when visitor_tracking is set to false' do
    let(:test_key) { "test" }
    let(:test_value) { 7 }

    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script('window.localStorage.clear();')
        before_tag_load.execute_script("window.localStorage.setItem('#{test_key}', #{test_value});")
      end
    end

    before do
      driver.execute_script("pi('identify_client', 'TK-421');")
      driver.execute_script("pi('visitor_tracking', false);")
    end

    it 'destroys all PI data from Local Storage' do
      it_stores_no_pi_data_in_local_storage
    end

    it 'non-PI data remains in Local Storage' do
      local_storage_item = find_in_local_storage(test_key)
      expect(local_storage_item).to eq(test_value.to_s)
    end

    context "when refresh" do
      before do
        driver.execute_script(<<~JS)
          window.PulseInsightsObject = new window.PulseInsights();
        JS
      end

      it 'does not add any PI data to Local Storage' do
        visitor_tracking = find_in_local_storage("pi_visitor_tracking")
        expect(visitor_tracking).to eq(false.to_s)

        it_stores_no_pi_data_in_local_storage
      end
    end

    # This makes more sense, grammatically
    # rubocop:disable RSpec/ContextWording
    context 'and later set to true' do
      before do
        driver.execute_script("pi('visitor_tracking', true);")
      end

      it 'some PI data should be immediately regenerated and stored' do
        udid = find_in_local_storage("pulse_insights_udid")
        expect(udid).not_to be_nil

        pageview_count = find_in_local_storage("pi_pageview_count")
        expect(pageview_count).to eq('1')

        visit_count = find_in_local_storage("pi_visit_count")
        expect(visit_count).to eq('1')
      end

      context 'then set to true again' do
        before do
          @udid = find_in_local_storage("pulse_insights_udid")
          @pageview_count = find_in_local_storage("pi_pageview_count")
          @visit_count = find_in_local_storage("pi_visit_count")
          driver.execute_script("pi('visitor_tracking', true);")
        end

        it 'has no effect on existing keys' do
          udid = find_in_local_storage("pulse_insights_udid")
          expect(udid).to eq(@udid)

          pageview_count = find_in_local_storage("pi_pageview_count")
          expect(pageview_count).to eq(@pageview_count)

          visit_count = find_in_local_storage("pi_visit_count")
          expect(visit_count).to eq(@visit_count)
        end
      end
    end
  end

  context 'when a tag is loaded' do
    let(:driver) { @driver = setup_driver_via_http }

    it 'updates timestamp' do
      # store log of the previous PI object & create a new PI object
      log_messages = driver.execute_script(<<~JS)
        window.previousLog = window.PulseInsightsObject.logMessages;
        window.PulseInsightsObject = new window.PulseInsights();
        return window.previousLog + window.PulseInsightsObject.logMessages;
      JS

      set_track_count = log_messages.scan('Set item in Local Storage pi_visit_track:').count
      expect(set_track_count).to eq(2) # timestamp is updated the number of times a PI object is initialized
    end
  end

  def it_stores_all_pi_data_in_local_storage
    pi_keys.each do |key|
      local_storage_item = find_in_local_storage(key)
      expect(local_storage_item).not_to be_nil
    end
  end

  def it_stores_no_pi_data_in_local_storage
    pi_keys.each do |key|
      local_storage_item = find_in_local_storage(key)
      expect(local_storage_item).to be_nil
    end
  end

  def find_in_local_storage(key)
    driver.execute_script("return window.localStorage.getItem('#{key}');")
  end
end
