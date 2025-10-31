# frozen_string_literal: true

require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Custom Content Link Click' do
  # TODO: Remove this "before" block after resolving https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    Submission.delete_all
    CustomContentLinkClick.delete_all
  end

  let(:account) { create(:account, custom_content_link_click_enabled: true) }
  let(:survey) { create(:survey_without_question, account: account) }

  let(:link_identifier) { SecureRandom.uuid }
  let(:custom_content) { "<a class='custom-content-link' href='https://test.com' data-pi-link-id='#{link_identifier}'>click this!</a>" }
  let!(:custom_content_question) { create(:custom_content_question, survey: survey, custom_content: custom_content) }

  describe "custom data transmission" do
    before do
      @driver = create_driver

      set_survey_to_debug_mode
    end

    context "when the survey has custom data" do
      before do
        @driver.execute_script("pi('set_custom_data', #{custom_data})")
        click_custom_content_link
      end

      context "when the data is null" do
        let(:custom_data) { nil }

        it "sends the custom data in its /custom_content_link_click request" do
          assert_custom_content_link_click_requested
          expect_link_click_logged

          expect(logged_custom_data).to eq "{\"data\":undefined}"
        end
      end

      context "when the data is a string" do
        let(:custom_data) { "'#{FFaker::Lorem.word}'" }

        it "sends the custom data in its /custom_content_link_click request" do
          assert_custom_content_link_click_requested
          expect_link_click_logged

          expect(logged_custom_data).to eq "{\"data\":\"#{custom_data.gsub("'", "")}\"}"
        end
      end

      context "when the data is an object" do
        let(:custom_data) { "{objectKey: 'some_value'}" }

        it "sends the custom data in its /custom_content_link_click request" do
          assert_custom_content_link_click_requested
          expect_link_click_logged

          expect(logged_custom_data).to eq "{\"objectKey\":\"some_value\"}"
        end
      end
    end
  end

  context 'when it is a one-at-a-time survey' do
    before do
      @driver = create_driver

      set_survey_to_debug_mode
    end

    it 'logs a custom content link click' do
      click_custom_content_link
      assert_custom_content_link_click_requested
      expect_link_click_logged
    end
  end

  context 'when it is an all-at-once survey' do
    before do
      survey.update(display_all_questions: true)

      @driver = create_driver

      set_survey_to_debug_mode
    end

    it 'logs a custom content link click' do
      click_custom_content_link
      assert_custom_content_link_click_requested
      expect_link_click_logged
    end
  end

  def create_driver
    setup_driver(html_test_file(html_test_page(account)))
  end

  def set_survey_to_debug_mode
    @driver.execute_script('window.PulseInsightsObject.debug(true)') # So clicking a link won't actually transfer to the next page
  end

  def click_custom_content_link
    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { @driver.find_element(xpath: "//a[@class='custom-content-link']") }
    @driver.find_element(xpath: "//a[@class='custom-content-link']").click
    sleep(1) # Waiting for a response from Rack app so the JS callback is complete where the logging takes place
  end

  def custom_content_link_click_query_parameters
    result = @driver.execute_script('return window.PulseInsightsObject.logMessages').detect do |log_message|
      uri = URI(log_message)
      uri.path == "/custom_content_link_click"
    rescue URI::InvalidURIError
      false
    end

    query_key_value_pairs = URI.decode_www_form(URI(result).query)
    query_key_value_pairs.to_h
  end

  def logged_custom_data
    custom_content_link_click_query_parameters["custom_data"]
  end

  def assert_custom_content_link_click_requested
    query_hash = custom_content_link_click_query_parameters

    expect(query_hash["question_id"].to_i).to eq custom_content_question.id
    expect(query_hash["link_identifier"]).to eq link_identifier
  end

  def expect_link_click_logged
    logs = @driver.execute_script('return window.PulseInsightsObject.logMessages').join(',')

    expect(logs).to include "Logged a custom content link click"
  end
end
