# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'All at once submission' do
  let!(:account) { create(:account) }
  let!(:survey) { create(:survey_without_question, account: account, display_all_questions: true, all_at_once_error_text: 'please fill answer!') }

  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:submit_button) { find_element({class: '_pi_all_questions_submit_button'}) }

  shared_examples "question supporting empty answer alerts" do
    context "when the answer is empty" do
      before do
        click_submit_button
      end

      it "has expected behaviour" do
        # "alerts answer is empty"
        expect(empty_answer_alert.text).to eq question.empty_error_text

        # "has aria-invalid = true"
        expect(invalid_input_element.attribute("aria-invalid")).to eq "true"

        # "has input control focused"
        expect(active_element).to eq focus_target
      end
    end

    context "when the answer isn't empty" do
      before do
        click_submit_button
        fill_target
      end

      it "has expected behaviour" do
        # "doesn't alert answer is empty"
        expect(empty_answer_alert.text).to eq ""

        # "has aria-invalid = false"
        expect(invalid_input_element.attribute("aria-invalid")).to eq "false"
      end
    end
  end

  describe "error messaging" do
    before do
      account.personal_data_setting.update(masking_enabled: true, phone_number_masked: true, email_masked: true)
    end

    let(:active_element) { driver.switch_to.active_element }
    let(:free_text_empty_answer_alert) { find_element({class: "_pi_free_text_question_empty_answer_alert"}) }
    let(:free_text_personal_data_alert) { find_element({class: "_pi_free_text_question_personal_data_alert"}) }
    let(:free_text_text_field) { find_element({class: "_pi_free_text_question_field"}) }
    let(:multiple_choices_empty_answer_alert) { find_element({class: "_pi_multiple_choices_empty_answer_alert"}) }
    let(:multiple_choices_count_alert) { find_element({class: "_pi_multiple_choices_count"}) }
    let(:multiple_choices_first_checkbox) { find_element({class: "_pi_checkbox"}) }
    let(:single_choice_menu) { find_element({tag_name: "select"}) }

    context "when empty error is enabled" do
      before do
        survey.update(all_at_once_empty_error_enabled: true)
      end

      context "with a free text question" do
        let!(:question) { create(:free_text_question, survey: survey, empty_error_text: "Your answer is empty!", error_text: "You are submitting personal data!") }

        before do
          driver.current_url
          sleep(1)
        end

        it_behaves_like "question supporting empty answer alerts" do
          let(:empty_answer_alert) { free_text_empty_answer_alert }
          let(:invalid_input_element) { free_text_text_field }
          let(:focus_target) { free_text_text_field }

          def fill_target
            insert_text_into_text_field("abcd")
          end
        end

        context "when the answer contains personal data" do
          before do
            insert_text_into_text_field("123456789")
            click_submit_button
          end

          it "has expected behaviour" do
            # "alerts answer contains personal data"
            expect(free_text_personal_data_alert.text).to eq question.error_text

            # "does not alert answer is empty"
            expect(free_text_empty_answer_alert.text).to eq ""

            # "has aria-invalid = true"
            expect(free_text_text_field.attribute("aria-invalid")).to eq "true"

            # "has text field focused"
            expect(active_element).to eq free_text_text_field
          end
        end
      end

      context "with a multiple choices question" do
        let(:question) { create(:multiple_choices_question, survey: survey, enable_maximum_selection: true, maximum_selection: 1, empty_error_text: "You have to choose at least one!") }

        before do
          survey.questions << question

          driver.current_url
          sleep(1)
        end

        it_behaves_like "question supporting empty answer alerts" do
          let(:empty_answer_alert) { multiple_choices_empty_answer_alert }
          let(:invalid_input_element) { multiple_choices_first_checkbox }
          let(:focus_target) { multiple_choices_first_checkbox }

          def fill_target
            click_multiple_choices_first_checkbox
          end
        end

        context "when the count is excessive" do
          before do
            click_all_checkboxes
            click_submit_button
          end

          context "when a custom message has been configured" do
            let(:question) { create(:multiple_choices_question, survey: survey, enable_maximum_selection: true, maximum_selection: 1, maximum_selections_exceeded_error_text: maximum_selections_exceeded_error_text) }
            let(:maximum_selections_exceeded_error_text) { "TOO MANY!" }

            it "alerts count is excessive" do
              expect(multiple_choices_count_alert.text).to eq maximum_selections_exceeded_error_text
            end
          end

          it "has expected behaviour" do
            # "alerts count is excessive"
            expect(multiple_choices_count_alert.text).to eq "Maximum of 1 please."

            # "doesn't alert answer is empty"
            expect(multiple_choices_empty_answer_alert.text).to eq ""

            # "has aria-invalid = true"
            expect(multiple_choices_first_checkbox.attribute("aria-invalid")).to eq "true"
            # "has the first check box focused"
            expect(active_element).to eq multiple_choices_first_checkbox
          end
        end
      end

      context "with a single choice question" do
        let(:question) { create(:single_choice_question, survey: survey, button_type: "menu", empty_error_text: "You have to choose one answer!") }

        before do
          survey.questions << question

          driver.current_url
          sleep(1)
        end

        it_behaves_like "question supporting empty answer alerts" do
          let(:empty_answer_alert) { find_element({class: "_pi_single_choice_empty_answer_alert"}) }
          let(:invalid_input_element) { single_choice_menu }
          let(:focus_target) { single_choice_menu }

          def fill_target
            select_single_choice_first_answer
          end
        end
      end

      context "with an NPS question" do
        let(:question) { create(:nps_question, survey: survey, empty_error_text: FFaker::Lorem.phrase) }

        before do
          survey.questions << question

          driver.current_url
          sleep(1)
        end

        it_behaves_like "question supporting empty answer alerts" do
          let(:empty_answer_alert) { find_element({class: "_pi_single_choice_empty_answer_alert"}) }
          let(:invalid_input_element) { find_element({xpath: "//ul[@class='_pi_answers_container']/li/a"}) }
          let(:focus_target) { invalid_input_element }

          def fill_target
            invalid_input_element.click
          end
        end
      end

      context "with a few different questions" do
        before do
          create(:single_choice_question, survey: survey, position: 0, button_type: "menu")
          create(:multiple_choices_question, survey: survey, position: 1)
          create(:free_text_question, survey: survey, position: 2)

          driver.current_url
          sleep(1)
        end

        context "when all the answers are empty" do
          before do
            click_submit_button
          end

          it "has the first invalid question focused" do
            expect(active_element).to eq single_choice_menu
          end
        end

        context "when only the first question has valid answer" do
          before do
            select_single_choice_first_answer
            click_submit_button
          end

          it "has the first invalid question focused" do
            expect(active_element).to eq multiple_choices_first_checkbox
          end
        end

        context "when only the last question has invalid answer" do
          before do
            select_single_choice_first_answer
            click_multiple_choices_first_checkbox
            click_submit_button
          end

          it "has the first invalid question focused" do
            expect(active_element).to eq free_text_text_field
          end
        end
      end
    end

    context "when empty error isn't enabled" do
      let(:question) { nil }

      before do
        survey.update(all_at_once_empty_error_enabled: false)
        survey.questions << question

        driver.current_url
        sleep(1)
      end

      context "with a free text question" do
        let(:question) { create(:free_text_question, survey: survey, empty_error_text: "Your answer is empty!", error_text: "You are submitting personal data!") }
        let(:empty_answer_alerts) { find_all_elements({class: "_pi_free_text_question_empty_answer_alert"}) }

        it "doesn't have an empty answer alert element" do
          expect(empty_answer_alerts).to be_nil
        end
      end

      context "with a multiple choices question" do
        let(:question) { create(:multiple_choices_question, survey: survey, enable_maximum_selection: true, maximum_selection: 1, empty_error_text: "You have to choose at least one!") }
        let(:empty_answer_alerts) { find_all_elements({class: "_pi_multiple_choices_empty_answer_alert"}) }

        it "doesn't have an empty answer alert element" do
          expect(empty_answer_alerts).to be_nil
        end
      end

      context "with a single choice question" do
        let(:question) { create(:single_choice_question, survey: survey, button_type: "menu", empty_error_text: "You have to choose one answer!") }
        let(:empty_answer_alerts) { find_all_elements({class: "_pi_single_choice_empty_answer_alert"}) }

        it "doesn't have an empty answer alert element" do
          expect(empty_answer_alerts).to be_nil
        end
      end
    end
  end

  # Fix in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1365
  # it 'ties the text inputs and the character counters correctly' do
  #   account.personal_data_setting.update(masking_enabled: true, phone_number_masked: true, email_masked: true)
  #   survey = create(:survey_without_question, account: account, display_all_questions: true)
  #   (1..3).each { |n| create(:question, content: "question #{n}", question_type: :free_text_question, survey: survey) }
  #
  #   sleep(1)
  #   submit_button = find_element({class: '_pi_all_questions_submit_button'})
  #
  #   text_inputs = find_all_elements({class: '_pi_free_text_question_field'})
  #   char_counters = find_all_elements({class: '_pi_free_text_question_characters_count'})
  #   personal_data_alerts = find_all_elements({class: '_pi_free_text_question_personal_data_alert'})
  #
  #   # just making the survey submittable
  #   text_inputs.each { |text_input| text_input.send_keys 'safe text' }
  #   expect(submit_button.attribute('data-submit-error')).to be nil
  #
  #   text_inputs.each_with_index do |text_input, index|
  #     personal_info = '1' * 10
  #     text_input.clear
  #     text_input.send_keys personal_info
  #
  #     # Character counter works correctly
  #     expect(char_counters[index].text).to match(/^#{personal_info.length}\//)
  #     (char_counters - [char_counters[index]]).each { |char_counter| expect(char_counter).not_to match(/^#{personal_info.length}\//) }
  #
  #     # Personal data alert works correctly
  #     expect(personal_data_alerts[index].css_value(:visibility)).to eq 'visible'
  #     (personal_data_alerts - [personal_data_alerts[index]]).each { |alert| expect(alert.css_value(:visibility)).not_to eq 'visible' }
  #
  #     # Submit button works correctly
  #     expect(submit_button.attribute('data-submit-error')).to eq 'true'
  #
  #     text_input.clear
  #     text_input.send_keys 'safe text' # just generating a key-up/key-press event to trigger the alert logic so it removes the alert text
  #   end
  # end

  private

  def click_submit_button
    submit_button.click
  end

  def click_all_checkboxes
    checkboxes = find_all_elements({class: "_pi-control-checkbox"})
    checkboxes.each(&:click)
  end

  def click_multiple_choices_first_checkbox
    multiple_choices_first_checkbox = find_element({class: "_pi-control-checkbox"})
    multiple_choices_first_checkbox.click
  end

  def insert_text_into_text_field(text)
    free_text_text_field.send_keys(text)
  end

  def select_single_choice_first_answer
    single_choice_menu.click
    first_option = find_all_elements({tag_name: 'option'})[1]
    first_option.click
  end
end
