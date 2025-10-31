# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "multiple_choice_question" do
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }

  let(:submit_button_class) { "_pi_multiple_choices_question_submit_button" }
  let(:counter_class) { "_pi_multiple_choices_count" }
  let(:checkbox_class) { "_pi-control-checkbox" }
  let(:submit_error_class) { "_pi_multiple_choices_question_submit_error" }

  let(:submit_button) { find_element({class: submit_button_class}) }
  let(:counter) { find_element({class: counter_class}) }
  let(:submit_error) { find_element({class: submit_error_class}) }
  let(:screen_reader_submit_errors) { find_all_elements({class: "_pi_screen_reader_only"}) }

  it_behaves_like "answers per row", :multiple_choices_question
  it_behaves_like "additional question content", :multiple_choices_question
  it_behaves_like "submit button label" do
    let(:submit_button_class_selector) { submit_button_class }
    let(:question_type) { :multiple_choices_question }
    let(:question) { nil }
  end

  describe "aria labels" do
    before do
      survey.questions << create(:multiple_choices_question, enable_maximum_selection: true, maximum_selection: 1)
    end

    context "when a single possible answer has been selected" do
      before do
        find_element({class: checkbox_class}).click
      end

      it "has expected behaviour" do
        # "has no role for its counter"
        expect(counter.attribute("role")).to be_nil

        # "has aria-disabled = false for its submit button"
        expect(submit_button.attribute("aria-disabled")).to eq "false"
      end
    end

    context "when too many possible answers have been selected" do
      before do
        checkboxes = find_all_elements({class: checkbox_class})

        checkboxes[0].click
        checkboxes[1].click
      end

      context "when a possible answer has been deselected" do
        before do
          find_element({class: "_pi-control-checkbox"}).click
        end

        it "has expected behaviour" do
          # "has no role for its counter"
          expect(counter.attribute("role")).to be_nil

          # "has aria-disabled = false for its submit button"
          expect(submit_button.attribute("aria-disabled")).to eq "false"
        end
      end
    end
  end

  describe "error messaging" do
    let!(:question) { create(:multiple_choices_question, survey: survey, empty_error_text: "You have to choose at least one.") }

    context "when the answer is empty" do
      before do
        click_submit_button
      end

      context "when a possible answer is selected" do
        before do
          click_first_checkbox
        end

        it "removes the empty answer alert" do
          expect(submit_error.text).to eq ""
        end
      end

      context "when the submit button is clicked again" do
        before do
          click_submit_button
          click_submit_button
        end

        it "has expected behaviour" do
          # "has the empty answer alert remained"
          expect(submit_error.text).to eq question.empty_error_text

          # "has screen reader alerts appended"
          expect(screen_reader_submit_errors.size).to eq 2
        end
      end
    end
  end

  # Make sure empty answer alert element doesn't appear in the DOM tree
  # to avoid style impacts on one-at-a-time surveys
  describe "DOM tree" do
    before do
      survey.questions << create(:multiple_choices_question, survey: survey)
    end

    let(:alert_label_containers) { find_all_elements({class: "_pi_multiple_choice_question_alert_label_container"}) }
    let(:empty_answer_alerts) { find_all_elements({class: "_pi_multiple_choices_empty_answer_alert"}) }

    it_behaves_like "alert containers"
  end

  it_behaves_like "randomizable possible answers" do
    let(:question_type) { :multiple_choices_question }
    let(:answer_elements) { find_all_elements({xpath: "//*[@class='_pi_answers_container']//input[@class='_pi_checkbox']"}) }

    def possible_answer_id_from_element(element)
      element.attribute("value").to_i
    end
  end

  private

  def click_submit_button
    submit_button.click
  end

  def click_first_checkbox
    first_checkbox = find_element({class: checkbox_class})
    first_checkbox.click
  end
end
