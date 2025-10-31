# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Custom data' do
  before do
    Account.delete_all
    Survey.delete_all
    Submission.delete_all
  end

  it "injects the custom data snippet from the accounts setup" do
    survey = create(:survey_with_account)
    account = survey.account

    account.custom_data_enabled = true
    account.custom_data_snippet = "pi('set_custom_data', {message: 'I come from the custom data snippet setup in the accounts page.'});"
    account.save

    response = start_and_answer_survey(account)

    expect(response).to include("Received custom data object.")
    expect(Submission.count).to eq(1)

    # fail sometimes without sleep. probably because it gets evaluated before a worker finishes running
    sleep(1)
    expect(Submission.first.custom_data).to eq('message' => 'I come from the custom data snippet setup in the accounts page.')
  end

  it "saves custom data to the Rack app with the submission" do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.save

    custom_tag_code = account.tag_code.sub("pi('get', 'surveys');", "pi('set_custom_data', {abc: 123}); pi('get', 'surveys');")
    allow(account).to receive(:tag_code).and_return(custom_tag_code)

    response = run_in_browser("return window.PulseInsightsObject.logMessages;", html_test_page(account))

    expect(response).to include("Received custom data object.")
    expect(Submission.count).to eq(1)
    expect(Submission.first.custom_data).to eq('abc' => 123)
  end

  private

  def start_and_answer_survey(account)
    testfile = html_test_file(html_test_page(account))
    driver = setup_driver(testfile)

    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { driver.find_element(class: '_pi_startButton') }

    start_button = driver.find_element(class: '_pi_startButton')
    start_button.click

    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { driver.find_element(class: '_pi_answers_container') }

    answer_button = driver.find_element(xpath: "/html/body//ul[@class='_pi_answers_container']/li/a/label")
    answer_button.click

    response = driver.execute_script('return window.PulseInsightsObject.logMessages;')
    driver.close

    response
  end
end
