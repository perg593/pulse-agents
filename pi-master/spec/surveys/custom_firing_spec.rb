# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Custom firing' do
  before do
    Account.delete_all
  end

  it "makes custom firing requests to the Rack app" do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.save

    custom_tag_code = account.tag_code.sub("pi('get', 'surveys');", "pi('present', #{survey.id});")
    allow(account).to receive(:tag_code).and_return(custom_tag_code)

    js = <<-js
    var page = require('webpage').create(),
      system = require('system'), address;

    address = system.args[1];

    page.onResourceRequested = function(request) {
      console.log('Request ' + request.url);
    };

    page.onResourceReceived = function(response) {
      console.log('Receive ' + response.url);
    };

    page.onLoadFinished = function(status) {
      console.log('OnLoadFinished triggered, exiting in 2 seconds.');
      setTimeout(function() {
        phantom.exit();
      }, 2000);
    };

    page.open(address, function(status) {
      if (status !== 'success') {
        console.log('FAIL to load: '+status);
        phantom.exit();
      }
    });
    js

    response = run_in_browser('', html_test_page(account))

    # TODO: make it work with Selenium -> https://gitlab.ekohe.com/ekohe/pi/-/issues/1185#note_635845
    # expect(response).to include("Request http://localhost:8888/surveys/#{survey.id}")
    # expect(response).to include("Receive http://localhost:8888/surveys/#{survey.id}")
    # expect(response).to include("&identifier=#{account.identifier}")
  end

  it "displays the survey" do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.save

    custom_tag_code = account.tag_code.sub("pi('get', 'surveys');", "pi('present', #{survey.id});")
    allow(account).to receive(:tag_code).and_return(custom_tag_code)

    custom_survey = custom_survey(account)

    expect(custom_survey.present?).to be true
    expect(custom_survey.text).to include('Hello, want to take a survey?')
  end

  private

  def custom_survey(account)
    testfile = html_test_file(html_test_page(account))
    driver = setup_driver(testfile)

    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { driver.find_element(id: '_pi_surveyWidget') }

    driver.find_element(id: '_pi_surveyWidget')
  end
end
