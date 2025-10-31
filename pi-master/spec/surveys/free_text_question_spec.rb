# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'free_text_question' do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:max_length) { 100 }
  let(:submit_button_class) { "_pi_free_text_question_submit_button" }

  before do
    Answer.delete_all
  end

  it_behaves_like "additional question content", :free_text_question
  it_behaves_like "submit button label" do
    let(:submit_button_class_selector) { submit_button_class }
    let(:question_type) { :free_text_question }
    let(:question) { nil }
  end

  describe "content" do
    let(:question) { create(:free_text_question, content: content, survey: survey, hint_text: hint_text) }
    let(:content) { FFaker::Lorem.phrase }
    let(:hint_text) { nil }
    let(:question_element) { find_element({xpath: "//div[@class='_pi_question _pi_question_free_text_question']"}) }

    before do
      survey.questions << question
    end

    it "renders the text content" do
      expect(question_element.text).to eq content
    end

    context "when hint text is provided" do
      let(:hint_text) { FFaker::Lorem.word }

      it "renders hint text" do
        answer_field = find_element({xpath: "//input[@class='_pi_free_text_question_field']"})

        expect(answer_field.attribute("placeholder")).to eq survey.questions.first.hint_text
      end
    end
  end

  describe "aria labels" do
    before do
      account.personal_data_setting.update(masking_enabled: true, email_masked: true)

      survey.questions << create(:free_text_question, max_length: max_length)

      @submit_button = find_element({class: submit_button_class})
      @personal_data_alert = find_element({class: '_pi_free_text_question_personal_data_alert'})
      @text_field = find_element({class: '_pi_free_text_question_field'})
    end

    context "when the input is valid" do
      before do
        insert_text_to_input(FFaker::Lorem.phrase)
      end

      it "has expected behaviour" do
        # "has an alert element with role = null"
        expect(@personal_data_alert.attribute("role")).to be_nil

        # "has a submit button with aria-disabled = false"
        expect(@submit_button.attribute("aria-disabled")).to eq "false"

        # "has aria-invalid = false"
        expect(@text_field.attribute("aria-invalid")).to eq "false"
      end
    end

    context "when the input is invalid" do
      before do
        insert_text_to_input(FFaker::Internet.email)
      end

      it "has expected behaviour" do
        # "has an alert element with role = 'alert'"
        expect(@personal_data_alert.attribute("role")).to eq "alert"

        # "has a submit button with aria-disabled = true"
        expect(@submit_button.attribute("aria-disabled")).to eq "true"

        # "has aria-invalid = true"
        expect(@text_field.attribute("aria-invalid")).to eq "true"
      end

      context "when the input later becomes valid" do
        before do
          insert_text_to_input([:backspace] * max_length)
        end

        it "has expected behaviour" do
          # "has an alert element with no role"
          expect(@personal_data_alert.attribute("role")).to be_nil

          # "has a submit button with aria-disabled = false"
          expect(@submit_button.attribute("aria-disabled")).to eq "false"

          # "has aria-invalid = false"
          expect(@text_field.attribute("aria-invalid")).to eq "false"
        end
      end
    end
  end

  describe "aria-required" do
    # TODO: Try to use :subject here
    let(:text_field) { find_element({class: '_pi_free_text_question_field'}) }

    context "when the question is optional" do
      before do
        survey.questions << create(:free_text_question, optional: true)
      end

      it "has no aria label" do
        expect(text_field.attribute("aria-required")).to be_nil
      end
    end

    context "when the question is mandatory" do
      before do
        survey.questions << create(:free_text_question, optional: false)
      end

      it "has an aria label" do
        expect(text_field.attribute("aria-required")).to eq "true"
      end
    end
  end

  # Make sure empty answer alert element doesn't appear in the DOM tree
  # to avoid style impacts on one-at-a-time surveys
  describe "DOM tree" do
    before do
      survey.questions << create(:free_text_question, survey: survey)
    end

    let(:alert_label_containers) { find_all_elements({class: "_pi_free_text_question_alert_label_container"}) }
    let(:empty_answer_alerts) { find_all_elements({class: "_pi_free_text_question_empty_answer_alert"}) }

    it_behaves_like "alert containers"
  end

  private

  def insert_text_to_input(text)
    text_input = find_element({class: '_pi_free_text_question_field'})
    text_input.send_keys(text)

    text_input.attribute('value')
  end

  def click_submit_button
    submit_button = find_element({class: submit_button_class})
    submit_button.click
  end
end
