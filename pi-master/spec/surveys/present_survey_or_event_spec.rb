# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Present Survey/Event" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_with_one_question, account: account, invitation: nil) }

  def assert_survey_rendered(survey)
    widget_logs = driver.execute_script("return window.PulseInsightsObject.logMessages;")

    expect(widget_logs).to include "Rendering survey #{survey.id}"
    expect(find_element({ id: "_pi_surveyWidgetContainer" }).present?).to be true
  end

  context "when pi_present parameter contains a number" do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script(<<-JS)
          const url = new URL(window.location);
          url.searchParams.set('pi_present', #{survey.id});
          window.history.pushState({}, '', url);
        JS
      end
    end

    before do
      driver.current_url
      sleep(1)
    end

    it "renders the survey specified in the parameter" do
      assert_survey_rendered(survey)
    end
  end

  context "when pi_present parameter only contains numbers, strings, and hyphens" do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script(<<-JS)
          const url = new URL(window.location);
          url.searchParams.set('pi_present', '#{pseudo_event}');
          window.history.pushState({}, '', url);
        JS
      end
    end

    let(:pseudo_event) { '12234-text' } # number, string, and hyphen

    before do
      create(:pseudo_event_trigger, survey: survey, pseudo_event: pseudo_event)

      driver.current_url
      sleep(1)
    end

    it "renders the survey specified in the parameter" do
      assert_survey_rendered(survey)
    end
  end

  context "when pi_present parameter contains something that can't be parsed as the id or the name of a survey" do
    let(:driver) do
      @driver = setup_driver_via_http do |before_tag_load|
        before_tag_load.execute_script(<<-JS)
          const url = new URL(window.location);
          url.searchParams.set('pi_present', 'zzzz%3f%26callback');
          window.history.pushState({}, '', url);
        JS
      end
    end

    it "doesn't render any surveys" do
      # Timeout is set to 3 seconds because the default 5 seconds seems too long for a element to be found,
      # but I don't want to impact the rest of the tests by changing the default.
      expect(find_element({ xpath: "//div[@id='_pi_surveyWidgetContainer']"}, timeout: 3).present?).to be false
    end
  end
end
