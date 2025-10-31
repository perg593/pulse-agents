# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Callback' do
  before do
    Account.delete_all
    Survey.delete_all
    Submission.delete_all
    Answer.delete_all
  end

  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }
  let(:start_button) { find_element({class: '_pi_startButton'}) }
  let(:close_button) { find_element({class: '_pi_closeButton'}) }
  let(:first_possible_answer_element) { find_element({xpath: "/html/body//ul[@class='_pi_answers_container']/li/a/label"}) }

  context "when custom_data_snippet (a.k.a. 'onimpression') is defined" do
    let(:account) do
      create(:account,
             custom_data_enabled: true,
             custom_data_snippet: "window.PulseInsightsObject.log('#{onimpression_message}');")
    end
    let(:onimpression_message) { 'Survey left an impression!' }

    before do
      create(:survey_with_one_question, account: account)
      driver.page_source
      sleep(1)
    end

    context "when survey is shown" do
      it "calls the account's custom_data_snippet" do
        expect(widget_log_messages).to include(onimpression_message)
      end
    end
  end

  context "when an onclose callback is defined" do
    let(:account) do
      create(:account,
             onclose_callback_enabled: true,
             onclose_callback_code: "window.PulseInsightsObject.log('#{onclose_message}');")
    end
    let(:onclose_message) { 'Survey closed!' }
    let(:oncomplete_message) { 'Survey completed!' }

    before do
      create(:survey_with_one_question, account: account, invitation: nil)
    end

    context "when completed" do
      before do
        # autoclose
        first_possible_answer_element.click
        sleep(1) # wait for callback to fire
      end

      it "does not call the onclose callback defined in the accounts setup when completed" do
        expect(widget_log_messages).not_to include(onclose_message)
      end
    end

    context "when an oncomplete callback is defined" do
      before do
        account.update(
          oncomplete_callback_enabled: true,
          oncomplete_callback_code: "window.PulseInsightsObject.log('#{oncomplete_message}');"
        )
      end

      context "when the close button is pressed without answering a question" do
        before do
          close_button.click
          sleep(1) # wait for callback to fire
        end

        it "calls the account's onclose callback" do
          expect(widget_log_messages).to include(onclose_message)
          expect(widget_log_messages).not_to include(oncomplete_message)
        end
      end
    end
  end

  describe 'Onview Callback' do
    let!(:survey) { create(:survey_with_account, invitation: nil) }
    let(:account) do
      survey.account.update(
        onview_callback_enabled: true,
        onview_callback_code: "window.PulseInsightsObject.log('#{onview_message}');"
      )
      survey.account
    end
    let(:onview_message) { 'Survey viewed!' }

    let(:page_element_trigger_js) { <<~JS }
      let div = document.createElement('div');
      div.classList.add('onview');
      document.body.appendChild(div);
    JS

    before do
      create(:page_element_visible_trigger, render_after_element_visible: '.onview', render_after_element_visible_enabled: true, survey: survey)
    end

    context "when the survey is not yet inside the viewport" do
      it "does not call the account's onview callback" do
        expect(widget_log_messages).not_to include(onview_message)
        expect(Submission.last.viewed_at).to be_nil
      end
    end

    context "when the survey is inside the viewport" do
      before do
        driver.execute_script(page_element_trigger_js)
        sleep(1) # wait for callback to fire
      end

      it "calls the account's onview callback" do
        expect(widget_log_messages).to include(onview_message)
        expect(Submission.last.viewed_at).not_to be_nil

        # The Tag JS sends "viewed_at" in UTC time, so the hours should be the same between the parameter and the column
        url = widget_log_messages.find { |log| log.include?('viewed_at=') }
        viewed_at = Rack::Utils.parse_query(URI(url).query)['viewed_at']
        expect(viewed_at).to include Submission.last.viewed_at.strftime("%T")
      end
    end
  end

  private

  def widget_log_messages
    driver.execute_script('return window.PulseInsightsObject.logMessages;')
  end
end
