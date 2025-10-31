# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Invitation" do
  let(:account) { create(:account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }
  let(:survey) { create(:survey_with_one_question, account: account) }

  let(:invitation_element) { find_element({class: "_pi_invitationTextContainer"}) }
  let(:button_element) { find_element({class: "_pi_startButton"}) }
  let(:question_element) { find_element({class: "_pi_question"}) }

  def expect_stale(element)
    element.displayed?
    RSpec::Expectations.fail_with("Expected #{element} to be deleted, but it's still in the DOM!")
    # rubocop:disable Lint/SuppressedException
  rescue Selenium::WebDriver::Error::StaleElementReferenceError => e
  end

  context "when invitation is present" do
    let(:invitation_text) { "welcome to the survey" }

    before do
      survey.update(invitation: invitation_text)
    end

    context "when the invitation text is clicked" do
      before do
        invitation_element.click
      end

      it "loads the first question" do
        expect_stale(invitation_element)
        expect(question_element.displayed?).to be true
      end
    end

    context "when button is not hidden" do
      it "renders the button" do
        expect(button_element.displayed?).to be true
        expect(button_element.text).to eq "Start"
      end

      context "when the button has custom text" do
        let(:button_text) { FFaker::Lorem.word }

        before do
          survey.update(invitation_button: button_text)
        end

        it "renders the custom text" do
          expect(button_element.displayed?).to be true
          expect(button_element.text).to eq button_text
        end
      end

      context "when the button is clicked" do
        before do
          button_element.click
        end

        it "loads the first question" do
          expect_stale(button_element)
          expect(question_element.displayed?).to be true
        end
      end
    end

    context "when button is hidden" do
      before do
        survey.update(invitation_button_disabled: true)
      end

      it "does not render the button" do
        expect(button_element).to be_nil
      end
    end
  end

  context "when invitation is absent" do
    before do
      survey.update(invitation: nil)
    end

    it "has expected behaviour" do
      # "does not render the invitation"
      expect(invitation_element).to be_nil

      # "renders the first question"
      expect(question_element.displayed?).to be true
    end
  end
end
