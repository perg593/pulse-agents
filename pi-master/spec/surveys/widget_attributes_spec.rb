# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Survey Attributes' do
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }
  let(:account) { create(:account, onanswer_callback_enabled: true) }

  # Fails intermittently. Fix in #1365.
  context 'when one at a time' do
    let(:survey) { create(:survey_without_question, account: account) }
    let(:wait) { Selenium::WebDriver::Wait.new(timeout: 10) }

    # SurveyJs has 3 ways to store "answer_content" - single choice(menu), single choice(standard/radio button) and multiple choice
    let!(:menu_question) { create(:question, button_type: :menu, survey: survey, position: 0) }
    let!(:radio_question) { create(:question, button_type: :radio, survey: survey, position: 1) }
    let!(:multi_choice_question) { create(:multiple_choices_question, survey: survey, position: 2) }

    it 'includes all necessary attributes in the widget' do
      menu_question.possible_answers.sort_by_position.first.update(next_question_id: radio_question.id)
      radio_question.possible_answers.sort_by_position.first.update(next_question_id: multi_choice_question.id)

      # Returns "answer_content" from log
      account.update(onanswer_callback_code: <<~JS)
        window.PulseInsightsObject.log(document.querySelector(`._pi_answers_container[data-question-id='${window.PulseInsightsObject.survey.question.id}']`).dataset['answerContent']);
      JS

      click_menu_question
      click_radio_question
      click_multi_choice_question

      response = driver.execute_script('return window.PulseInsightsObject.logMessages;')
      expect(response).to include menu_question.possible_answers.first.content
      expect(response).to include radio_question.possible_answers.first.content
      expect(response).to include multi_choice_question.possible_answers.pluck(:content).join(',')
    end
  end

  # context 'when all at once' do
  #   it 'includes all necessary attributes in the widget' do
  #     survey.update(display_all_questions: true)
  #
  #     click_menu_question
  #     click_radio_question
  #     click_multi_choice_question
  #
  #     answer_content = driver.find_element(xpath: "//*[@class='_pi_answers_container'][1]").attribute('data-answer-content')
  #     expect(answer_content).to eq menu_question.possible_answers.sort_by_position.first.content
  #     answer_content = driver.find_element(xpath: "//*[@class='_pi_answers_container'][2]").attribute('data-answer-content')
  #     expect(answer_content).to eq radio_question.possible_answers.sort_by_position.first.content
  #     answer_content = driver.find_element(xpath: "//*[@class='_pi_answers_container'][3]").attribute('data-answer-content')
  #     expect(answer_content).to eq multi_choice_question.possible_answers.sort_by_position.pluck(:content).join(',')
  #   end
  # end

  private

  def click_menu_question
    wait.until { driver.find_element(xpath: '//select[@class="_pi_select"]/option[2]') } # The index starts from 1, and 1 is "Select an aption"
    driver.find_element(xpath: '//select[@class="_pi_select"]/option[2]').click
  end

  def click_radio_question
    # The index starts from 1
    selector = "//ul[@class='_pi_answers_container'][@data-question-id='#{radio_question.id}']/li[1]//span[@class='_pi_radio_button_outer']"
    wait.until { driver.find_element(xpath: selector) }
    driver.find_element(xpath: selector).click
  end

  def click_multi_choice_question
    possible_answer_list_item_selector = "//ul[@class='_pi_answers_container'][@data-question-id='#{multi_choice_question.id}']/li"
    wait.until { driver.find_element(xpath: possible_answer_list_item_selector) }

    label_selector = "//label[@class='_pi-control _pi-control-checkbox']"

    first_possible_answer_selector = "#{possible_answer_list_item_selector}[1]#{label_selector}"
    second_possible_answer_selector = "#{possible_answer_list_item_selector}[2]#{label_selector}"

    driver.find_element(xpath: first_possible_answer_selector).click
    driver.find_element(xpath: second_possible_answer_selector).click
    driver.find_element(xpath: "//*[input[@class='_pi_multiple_choices_question_submit_button']|input[@class='_pi_all_questions_submit_button']]").click
  end
end
