# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "slider_question" do
  # TODO: Remove this "before" block after resolving https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    Answer.delete_all
  end

  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:slider_question) { create(:slider_question, survey: survey, content: content) }
  let(:content) { FFaker::Lorem.phrase }

  let(:slider_xpath) { "//ul[@class='_pi_answers_container'][@data-question-id=#{slider_question.id}]//div[contains(@class, '_pi_slider')]" }
  let(:hidden_slider_css_selector) { '_pi_hidden_slider' }
  let(:pip_css_selector) { 'noUi-value' }

  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }
  let(:submit_button_class) { "_pi_slider_question_submit_button" }

  it_behaves_like "submit button label" do
    let(:submit_button_class_selector) { submit_button_class }
    let(:question_type) { :slider_question }
    let(:question) { nil }
  end

  describe "text formatting" do
    before do
      survey.questions << slider_question
    end

    it_behaves_like "text formatting", :content do
      let(:element) { find_element({class: "_pi_question"}) }
    end

    describe "label text formatting" do
      let(:label_element) { find_element({class: "noUi-value"}) }
      let(:label_content) { FFaker::Lorem.word }

      before do
        slider_question.possible_answers.first.update(content: label_content)
      end

      it_behaves_like "text formatting", :label_content do
        let(:element) { label_element }
      end
    end
  end

  describe 'Appearance' do
    before do
      find_element({xpath: slider_xpath})
    end

    it 'sets a start position correctly' do
      current_position = driver.execute_script <<-JS
        answerContainer = document.querySelector('._pi_answers_container');
        currentPosition = answerContainer.querySelector('._pi_slider').noUiSlider.get();
        return parseInt(currentPosition);
      JS
      expect(current_position).to eq slider_question.slider_start_position
    end

    it 'sets labels to the pips correctly' do
      pip_labels = driver.execute_script("return [...document.querySelectorAll('.#{pip_css_selector}')].map((pip) => pip.innerText)")
      slider_possible_answers = slider_question.reload.possible_answers.sort_by_position
      slider_possible_answers.each.with_index { |possible_answer, index| expect(pip_labels[index]).to eq possible_answer.content }
    end
  end

  describe 'General functions' do
    describe 'Answer recording' do
      let(:possible_answer) { slider_question.reload.possible_answers.take }

      context 'when there is no submit button' do
        it 'records the selected answer correctly' do
          slider_question.update(slider_submit_button_enabled: false)

          find_element({xpath: slider_xpath})

          find_all_elements({class: pip_css_selector})[possible_answer.position].click

          sleep(1) # Ensure that Rack app has processed the request to record the selected answer
          answer = Answer.first
          expect(answer.question_id).to eq slider_question.id
          expect(answer.question_type).to eq slider_question.question_type
          expect(answer.possible_answer_id).to eq possible_answer.id
        end
      end

      context 'when there is a submit button' do
        it 'records the selected answer correctly' do
          find_element({xpath: slider_xpath})

          find_all_elements({class: pip_css_selector})[possible_answer.position].click
          submit_button_element.click

          sleep(1) # Ensure that Rack app has processed the request to record the selected answer
          answer = Answer.first
          expect(answer.question_id).to eq slider_question.id
          expect(answer.question_type).to eq slider_question.question_type
          expect(answer.possible_answer_id).to eq possible_answer.id
        end
      end
    end

    describe 'Next question rendering' do
      let(:next_question) { create(:question, survey: survey, position: 1) }
      let(:glue_possible_answer) { slider_question.reload.possible_answers.take }

      before do
        glue_possible_answer.update(next_question: next_question)
      end

      context 'when there is no submit button' do
        it 'renders the next question' do
          slider_question.update(slider_submit_button_enabled: false)

          find_element({xpath: slider_xpath})

          find_all_elements({class: pip_css_selector})[glue_possible_answer.position].click

          expect(question_element(next_question).present?).to be true
        end
      end

      context 'when there is a submit button' do
        it 'renders the next question' do
          find_element({xpath: slider_xpath})

          find_all_elements({class: pip_css_selector})[glue_possible_answer.position].click
          submit_button_element.click

          expect(question_element(next_question).present?).to be true
        end
      end
    end
  end

  # We place a range input behind noUiSlider to interact with screen readers because they don't work well with noUiSlider
  describe 'Hidden slider' do
    let(:possible_answer) { slider_question.reload.possible_answers.take }

    before do
      find_element({xpath: slider_xpath})
    end

    it 'keeps noUiSlider in sync' do
      # Moving the hidden input by firing a "change" event manually
      driver.execute_script <<-JS
        hiddenSlider = document.querySelector('.#{hidden_slider_css_selector}');
        hiddenSlider.setAttribute('value', #{possible_answer.position});
        hiddenSlider.dispatchEvent(new Event('change'));
      JS

      # Verifying that noUiSlider is in sync
      current_slider_position = driver.execute_script <<-JS
        answerContainer = document.querySelector('._pi_answers_container');
        currentPosition = answerContainer.querySelector('._pi_slider').noUiSlider.get();
        return parseInt(currentPosition);
      JS
      expect(current_slider_position).to eq possible_answer.position

      submit_button_element.click

      sleep(1) # Ensure that Rack app has processed the request to record the selected answer
      answer = Answer.first
      expect(answer.question_id).to eq slider_question.id
      expect(answer.question_type).to eq slider_question.question_type
      expect(answer.possible_answer_id).to eq possible_answer.id
    end

    it 'moves along with noUiSlider' do
      # Moving noUiSlider by clicking one of the pips because I couldn't figure out how to fire a change event on noUiSlider manually
      find_all_elements({class: pip_css_selector})[possible_answer.position].click

      expect(find_element({class: hidden_slider_css_selector}).attribute('value').to_i).to eq possible_answer.position
      expect(find_element({class: hidden_slider_css_selector}).attribute('aria-valuenow').to_i).to eq possible_answer.position
      expect(find_element({class: hidden_slider_css_selector}).attribute('aria-valuetext')).to eq possible_answer.content
    end
  end

  describe 'All-at-once surveys' do
    before do
      survey.update(display_all_questions: true)

      create(:question, survey: survey, position: 1)
      create(:multiple_choices_question, survey: survey, position: 2)
      create(:free_text_question, survey: survey, position: 3)
    end

    describe 'Empty error text' do
      let(:empty_error_text) { 'please submit' }

      before do
        slider_question.update(empty_error_text: empty_error_text)
      end

      # TODO: #1365 intermittent failure (E.g. https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/jobs/307827)
      # context 'when empty error text feature is enabled' do
      #   it 'displays the empty error text if submitted with no answer' do
      #     survey.update(all_at_once_empty_error_enabled: true)
      #
      #     find_element({xpath: slider_xpath})
      #
      #     expect(all_at_once_empty_error_element.text).to be_empty
      #     click_all_at_once_submit_button
      #     expect(all_at_once_empty_error_element.text).to eq empty_error_text
      #
      #     click_random_possible_answer(slider_question)
      #     expect(all_at_once_empty_error_element.text).to be_empty
      #   end
      # end

      context 'when empty error text feature is disabled' do
        it 'does not have the empty error element' do
          find_element({xpath: slider_xpath})
          expect(find_all_elements({class: '_pi_all_at_once_slider_question_empty_answer_alert'})).to be_nil
        end
      end

      def all_at_once_empty_error_element
        find_element({class: '_pi_all_at_once_slider_question_empty_answer_alert'})
      end
    end

    describe 'aria-invalid attribute' do
      # TODO: #1365 intermittent failure (E.g. https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/jobs/307827)
      # context 'when empty error text feature is enabled' do
      #   it 'sets aria-invalid to true on the hidden input beneath noUiSlider' do
      #     survey.update(all_at_once_empty_error_enabled: true)
      #
      #     find_element({xpath: slider_xpath})
      #
      #     expect(find_element({class: hidden_slider_css_selector}).attribute('aria-invalid')).to be_nil
      #     click_all_at_once_submit_button
      #     expect(find_element({class: hidden_slider_css_selector}).attribute('aria-invalid')).to eq 'true'
      #
      #     click_random_possible_answer(slider_question)
      #     expect(find_element({class: hidden_slider_css_selector}).attribute('aria-invalid')).to be_nil
      #   end
      # end

      context 'when empty error text feature is disabled' do
        it 'does not set aria-invalid to true on the hidden input beneath noUiSlider' do
          find_element({xpath: slider_xpath})

          expect(find_element({class: hidden_slider_css_selector}).attribute('aria-invalid')).to be_nil
          click_all_at_once_submit_button
          expect(find_element({class: hidden_slider_css_selector}).attribute('aria-invalid')).to be_nil
        end
      end
    end

    # TODO: #1365 intermittent failure (https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/jobs/312044)
    # describe 'Browser focus' do
    #   context 'when empty error text feature is enabled and the top question is of slider type' do
    #     it 'applies the focus on the hidden slider' do
    #       survey.update(all_at_once_empty_error_enabled: true)
    #
    #       find_element({xpath: slider_xpath})
    #
    #       click_all_at_once_submit_button
    #       expect(driver.execute_script('return document.activeElement').attribute('class')).to eq hidden_slider_css_selector
    #       click_random_possible_answer(slider_question)
    #       expect(driver.execute_script('return document.activeElement').attribute('class')).not_to eq hidden_slider_css_selector
    #     end
    #   end
    # end

    def click_random_possible_answer(slider_question)
      possible_answer = slider_question.possible_answers.take
      find_all_elements({class: pip_css_selector})[possible_answer.position].click
    end

    def click_all_at_once_submit_button
      find_element({class: '_pi_all_questions_submit_button'}).click
    end
  end

  describe 'One-at-a-time surveys' do
    it 'requires interaction before submission' do
      empty_error_text = 'Please select'
      slider_question.update(empty_error_text: empty_error_text)

      empty_error_text2 = 'Please give an answer'
      slider_question2 = create(:slider_question, survey: survey, empty_error_text: empty_error_text2, position: 1)

      # Connecting 2 slider questions to verify that interaction is required in the consequent question
      glue_possible_answer = slider_question.possible_answers.take
      glue_possible_answer.update(next_question: slider_question2)

      find_element({xpath: slider_xpath})

      # Verifying that interaction is required in the first question
      expect(submit_button_error_element.text).to be_empty
      submit_button_element.click
      expect(submit_button_error_element.text).to eq empty_error_text

      # Proceeding to the 2nd question
      find_all_elements({class: pip_css_selector})[glue_possible_answer.position].click
      submit_button_element.click
      expect(question_element(slider_question2).present?).to be true

      # Verifying that interaction is required in the 2nd question
      expect(submit_button_error_element.text).to be_empty
      submit_button_element.click
      expect(submit_button_error_element.text).to eq empty_error_text2

      # Submitting an answer to the 2nd question
      consequent_possible_answer = slider_question2.possible_answers.take
      find_all_elements({class: pip_css_selector})[consequent_possible_answer.position].click
      submit_button_element.click

      sleep(1) # Ensure that Rack app has processed the requests to record the both answers
      expect(Answer.count).to eq Question.count
      expect(Answer.first.question_id).to eq slider_question.id
      expect(Answer.first.possible_answer_id).to eq glue_possible_answer.id
      expect(Answer.last.question_id).to eq slider_question2.id
      expect(Answer.last.possible_answer_id).to eq consequent_possible_answer.id
    end

    def submit_button_error_element
      find_element({class: '_pi_slider_question_submit_button_error'})
    end
  end

  def question_element(question)
    question_element_xpath = "//ul[@class='_pi_answers_container'][@data-question-id=#{question.id}]"
    find_element({xpath: question_element_xpath})
  end

  def submit_button_element
    find_element({class: submit_button_class})
  end
end
