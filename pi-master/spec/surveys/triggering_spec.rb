# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Survey Triggering" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  shared_examples "a survey trigger" do
    # Do whatever satisfies the trigger
    def satisfy_trigger
      raise NotImplementedError, "You must implement 'satisfy_trigger'"
    end

    context "when the trigger has not been satisfied" do
      it "renders no survey" do
        expect(find_widget).to be_nil
      end
    end

    context "when the trigger has been satisfied" do
      before do
        satisfy_trigger
      end

      it "renders the survey" do
        expect(find_widget).not_to be_nil
      end
    end
  end

  context "when a render_after_x_seconds trigger is defined" do
    # Firing up selenium might take 10s, so we should wait longer
    # to be sure the widget is only loading after render_after_x_seconds
    let(:seconds_to_wait) { 15 }

    before do
      create(:page_after_seconds_trigger, survey: survey,
             render_after_x_seconds: seconds_to_wait)
    end

    it_behaves_like "a survey trigger" do
      def satisfy_trigger
        driver.current_url # Waking up the lazy-loaded driver
        sleep(seconds_to_wait)
      end
    end
  end

  context "when a render_after_x_percent_scroll trigger is defined" do
    let(:scroll_threshold_percentage) { 70 }
    let(:body_height) { 2000 }
    let(:html_height) { 1000 }
    # 6 was found through trial and error. It's hard to be precise here
    let(:pixels_to_pass_threshold) { 6 + ((body_height - html_height) * scroll_threshold_percentage / 100.0) }

    # To help with troubleshooting
    # let(:get_scroll_percentage_js) { "return (document.documentElement.scrollTop || document.body.scrollTop) / ((document.documentElement.scrollHeight || document.body.scrollHeight) - document.documentElement.clientHeight) * 100;" }

    before do
      create(:page_scroll_trigger, survey: survey,
             render_after_x_percent_scroll: scroll_threshold_percentage)
      stretch_page
    end

    it_behaves_like "a survey trigger" do
      def satisfy_trigger
        scroll_amount = pixels_to_pass_threshold
        driver.execute_script("window.scrollBy(0,#{scroll_amount})")
      end
    end

    context "when the scroll threshold has almost been crossed" do
      before do
        scroll_amount = pixels_to_pass_threshold - 1
        driver.execute_script("window.scrollBy(0,#{scroll_amount})")
      end

      it "renders no survey" do
        expect(find_widget).to be_nil
      end
    end
  end

  context "when a page_element_clicked trigger is defined" do
    let(:trigger_element_id) { "foo" }
    let(:trigger_element_selector) { "##{trigger_element_id}" }

    before do
      create(:page_element_clicked_trigger, survey: survey,
             render_after_element_clicked: trigger_element_selector)

      add_trigger_element_js = <<~JS
        let button = document.createElement('button');
        button.setAttribute('id', '#{trigger_element_id}');
        document.body.appendChild(button);
      JS

      driver.execute_script(add_trigger_element_js)
    end

    it_behaves_like "a survey trigger" do
      def satisfy_trigger
        sleep(0.2) # Wait until click listener has been added
        find_element({id: trigger_element_id}).click
      end
    end
  end

  context "when a page_intent_exit trigger is defined" do
    before do
      create(:page_intent_exit_trigger, survey: survey)
    end

    it_behaves_like "a survey trigger" do
      # https://github.com/carlsednaoui/ouibounce
      # Ouibounce fires when the mouse cursor moves close to (or passes) the top of the viewport
      def satisfy_trigger
        driver.current_url # Waking up the lazy-loaded driver
        sleep(0.5) # Accommodates ouibounce timer
        driver.execute_script("let event = new Event('mouseleave', {view: window, bubbles: true, cancelable: true}); document.body.dispatchEvent(event);") # make ouibounce think the mouse is above the viewport
        sleep(1) # Accommodates ouibounce delay
      end
    end
  end

  context "when a page_element_visible trigger is defined" do
    let(:trigger_element_id) { "foo" }
    let(:render_after_element_visible) { "##{trigger_element_id}" }
    let(:body_height) { 2000 }
    let(:html_height) { 1000 }

    before do
      create(:page_element_visible_trigger, survey: survey,
             render_after_element_visible: render_after_element_visible)

      add_trigger_element_js = <<~JS
        let triggerElement = document.createElement('div');
        triggerElement.setAttribute('id', '#{trigger_element_id}');
        triggerElement.style = 'position: absolute; bottom: 0px';
        document.body.style.position = 'relative';
        document.body.appendChild(triggerElement);
      JS

      stretch_page

      driver.execute_script(add_trigger_element_js)
    end

    it_behaves_like "a survey trigger" do
      def satisfy_trigger
        driver.execute_script("document.getElementById('#{trigger_element_id}').scrollIntoView()")
      end
    end
  end

  context "when a text_on_page trigger is defined" do
    let(:trigger_element_id) { "foo" }
    let(:text_on_page_selector) { "##{trigger_element_id}" }
    let(:text_on_page_value) { "abc" }
    let(:add_trigger_element_js) { <<~JS }
      let triggerElement = document.createElement('div');
      triggerElement.setAttribute('id', '#{trigger_element_id}');
      document.body.appendChild(triggerElement);
    JS

    before do
      @trigger = create(
        :text_on_page_trigger,
        survey: survey,
        text_on_page_selector: text_on_page_selector,
        text_on_page_value: text_on_page_value,
        text_on_page_presence: false
      )
    end

    def assign_trigger_text(inner_html)
      driver.execute_script("document.getElementById('#{trigger_element_id}').innerHTML = '#{inner_html}'")
    end

    context "when text_on_page_presence is true" do
      before do
        @trigger.update(text_on_page_presence: true)
        driver.execute_script(add_trigger_element_js)
      end

      it_behaves_like "a survey trigger" do
        def satisfy_trigger
          assign_trigger_text("123#{text_on_page_value}456")
        end
      end
    end

    context "when text_on_page_presence is false" do
      before do
        @trigger.update(text_on_page_presence: false)
        driver.execute_script(add_trigger_element_js)
        assign_trigger_text(text_on_page_value)
      end

      it_behaves_like "a survey trigger" do
        def satisfy_trigger
          assign_trigger_text("123456")
        end
      end
    end
  end

  def find_widget
    find_element({id: "_pi_surveyWidgetContainer"})
  end

  def stretch_page
    driver.execute_script("document.documentElement.style.height = '#{html_height}px'")
    driver.execute_script("document.body.style.height = '#{body_height}px'")
  end
end
