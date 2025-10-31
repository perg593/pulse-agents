# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Present Poll" do
  # TODO: Remove this "before" block after resolving https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
  end

  let(:account) { create(:account) }
  let(:survey) { create(:survey_with_one_question, account: account, invitation: nil, poll_enabled: true) }

  # Disable until we get setup_driver_via_http tests working consistently
  # context "when called with 'pi_poll' parameter" do
  #   it "renders the poll" do
  #     question = survey.questions.reload.first
  #
  #     @driver = setup_driver_via_http do |before_tag_load|
  #       before_tag_load.execute_script(<<-JS)
  #         const url = new URL(window.location);
  #         url.searchParams.set('pi_present', #{survey.id});
  #         url.searchParams.set('pi_poll', #{question.id});
  #         window.history.pushState({}, '', url);
  #       JS
  #     end
  #
  #     question_poll_is_displayed
  #   end
  # end

  context "when called from pi function" do
    it "renders the poll" do
      another_question = create(:question, survey: survey)

      @driver = setup_driver(html_test_file(html_test_page(account)))
      @driver.execute_script("pi('present_poll', #{survey.id}, #{another_question.id})")

      question_poll_is_displayed
    end
  end

  def question_poll_is_displayed
    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { @driver.find_element(xpath: "//div[@class='_pi_pollContainer']") }
    expect(@driver.find_element(xpath: "//div[@class='_pi_pollContainer']").present?).to be true
  end
end
