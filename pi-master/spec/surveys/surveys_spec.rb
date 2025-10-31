# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

# rubocop:disable RSpec/EmptyExampleGroup
describe 'Account tag code' do
  # before do
  #   Account.delete_all
  #   Submission.delete_all
  # end
  #
  # let(:account) { create(:account) }
  #
  # it "is able to load the javascript library and define the pi() function" do
  #   result = run_in_browser("return typeof(pi)", html_test_page(account))
  #   expect(result).to eq("function")
  # end
  #
  # it "loads PulseInsights javascript library" do
  #   result = run_in_browser("return typeof(window.PulseInsights)", html_test_page(account))
  #   expect(result).to eq("function")
  # end
  #
  # # TODO: make it work with Selenium -> https://gitlab.ekohe.com/ekohe/pi/-/issues/1185#note_635845
  # # it "triggers a serve get request to the rack app with the identifier in the query string" do
  # #   js = <<-js
  # #   var page = require('webpage').create(),
  # #     system = require('system'), address;
  # #
  # #   address = system.args[1];
  # #
  # #   page.onResourceRequested = function(request) {
  # #     console.log('Request ' + request.url);
  # #   };
  # #
  # #   page.onResourceReceived = function(response) {
  # #     console.log('Receive ' + response.url);
  # #   };
  # #
  # #   page.onLoadFinished = function(status) {
  # #     console.log('OnLoadFinished triggered, exiting in one second.');
  # #     setTimeout(function() {
  # #       phantom.exit();
  # #     }, 1000);
  # #   };
  # #
  # #   page.open(address, function(status) {
  # #     if (status !== 'success') {
  # #       console.log('FAIL to load: '+status);
  # #       phantom.exit();
  # #     }
  # #   });
  # #   js
  # #
  # #   response = run_in_browser('', html_test_page(account), helper_options: { network_log: true })
  # #
  # #   expect(response).to include("Request http://localhost:8888/serve?")
  # #   expect(response).to include("Receive http://localhost:8888/serve?")
  # #   expect(response).to include("&identifier=#{account.identifier}")
  # # end
  #
  # context 'when survey is shown on single page app' do
  #   before do
  #     @survey = create(:survey, account: account, single_page: true)
  #
  #     @driver = setup_driver_via_http do |before_tag_load|
  #       before_tag_load.execute_script('window.localStorage.clear();')
  #     end
  #
  #     @driver.execute_script("pi('identify_client', 'TK-421');")
  #     @driver.execute_script("pi('get', #{@survey.id});")
  #   end
  #
  #   after do
  #     @driver.close
  #   end
  #
  #   it 'increments pageview count when onhashchange event is fired' do
  #     @driver.execute_script("location.hash = 'new_location';")
  #
  #     result = @driver.execute_script("return window.localStorage.getItem('pi_pageview_count');")
  #     expect(result).to eq("2")
  #   end
  #
  #   it "increments pageview count when the browser's session history stack is modified" do
  #     @driver.execute_script("history.pushState({'foo': 2}, 'nothing', 'anywhere.html');")
  #
  #     result = @driver.execute_script("return window.localStorage.getItem('pi_pageview_count');")
  #     expect(result).to eq("2")
  #   end
  # end
  #
  # context 'when survey is shown on a non-single page app' do
  #   before do
  #     @survey = create(:survey, account: account, single_page: false)
  #
  #     @driver = setup_driver_via_http do |before_tag_load|
  #       before_tag_load.execute_script('window.localStorage.clear();')
  #     end
  #
  #     @driver.execute_script("pi('identify_client', 'TK-421');")
  #     @driver.execute_script("pi('get', #{@survey.id});")
  #     @driver.execute_script("pi('spa', false);")
  #   end
  #
  #   after do
  #     @driver.close
  #   end
  #
  #   it 'does not increment pageview count when onhashchange event is fired' do
  #     @driver.execute_script("location.hash = 'new_location';")
  #
  #     result = @driver.execute_script("return window.localStorage.getItem('pi_pageview_count');")
  #     expect(result).to eq("1")
  #   end
  #
  #   it "does not increment pageview count when the browser's session history stack is modified" do
  #     @driver.execute_script("history.pushState({'foo': 2}, 'nothing', 'anywhere.html');")
  #
  #     result = @driver.execute_script("return window.localStorage.getItem('pi_pageview_count');")
  #     expect(result).to eq("1")
  #   end
  # end
  #
  # describe "PageView and Visit" do
  #   context 'when user has never visited the page' do
  #     it "sets a submission's pageview_count and visit_count to 1" do
  #       create(:survey, status: :live, account: account)
  #
  #       setup_driver_via_http
  #       sleep 1 # wait for a submission record to be created by Rack app
  #
  #       expect(Submission.count).to eq 1
  #       expect(Submission.first.pageview_count).to eq 1
  #       expect(Submission.first.visit_count).to eq 1
  #     end
  #   end
  #
  #   context 'when user has visited the page' do
  #     let(:device) { create(:device) }
  #     let(:survey) { create(:survey, status: :live, account: account) }
  #
  #     before do
  #       create(:submission, device: device, survey: survey)
  #     end
  #
  #     context 'when it was within 20 mins' do
  #       it "increments a submission's pageview_count" do
  #         last_visit_epoch = (Time.current.to_i * 1000).to_s # Epoch in Javascript is in millisecond
  #         setup_driver_via_http do |before_tag_load|
  #           before_tag_load.execute_script('window.localStorage.clear();')
  #           before_tag_load.manage.add_cookie(name: 'pulse_insights_udid', value: device.udid)
  #           before_tag_load.manage.add_cookie(name: 'pi_visit_track', value: last_visit_epoch)
  #           before_tag_load.manage.add_cookie(name: 'pi_visit_count', value: '1')
  #           before_tag_load.manage.add_cookie(name: 'pi_pageview_count', value: '1')
  #         end
  #         sleep 1 # wait for a submission record to be created by Rack app
  #
  #         expect(Submission.count).to eq 2
  #         expect(Submission.last.pageview_count).to eq 2
  #         expect(Submission.last.visit_count).to eq 1
  #       end
  #     end
  #
  #     context 'when it was more than 20 mins earlier' do
  #       it "increments a submission's visit_count" do
  #         last_visit_epoch = (25.minutes.ago.to_i * 1000).to_s # Epoch in Javascript is in millisecond
  #         setup_driver_via_http do |before_tag_load|
  #           before_tag_load.execute_script('window.localStorage.clear();')
  #           before_tag_load.manage.add_cookie(name: 'pulse_insights_udid', value: device.udid)
  #           before_tag_load.manage.add_cookie(name: 'pi_visit_track', value: last_visit_epoch)
  #           before_tag_load.manage.add_cookie(name: 'pi_visit_count', value: '1')
  #           before_tag_load.manage.add_cookie(name: 'pi_pageview_count', value: '1')
  #         end
  #         sleep 1 # wait for a submission record to be created by Rack app
  #
  #         expect(Submission.count).to eq 2
  #         expect(Submission.last.pageview_count).to eq 1
  #         expect(Submission.last.visit_count).to eq 2
  #       end
  #     end
  #   end
  # end
end
