# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Rerendering Survey" do
  let(:account) { create(:account) }
  let(:inline_boilerplate) { { account: account, survey_type: "inline", inline_target_selector: '#inline_survey_target_area' } }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 10) } # seconds
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  context "with an inline survey originally" do
    context "when survey is above target" do
      before do
        @inline_survey = create(:survey, inline_boilerplate.merge(inline_target_position: 2))
        @docked_widget_survey = create(:survey, account: account, survey_type: "docked_widget", status: "draft")
      end

      it "destroys survey and displays another" do
        expect_survey_is_replaced @inline_survey, @docked_widget_survey
      end
    end

    context "when survey is below target" do
      before do
        @inline_survey = create(:survey, inline_boilerplate.merge(inline_target_position: 3))
        @docked_widget_survey = create(:survey, account: account, survey_type: "docked_widget", status: "draft")
      end

      it "destroys survey and displays another" do
        expect_survey_is_replaced @inline_survey, @docked_widget_survey
      end
    end
  end

  context "with a docked widget survey originally" do
    before do
      @docked_widget_survey = create(:survey, account: account, survey_type: 0)
      @inline_survey = create(:survey, inline_boilerplate.merge(status: "draft", inline_target_position: 2))
    end

    it "destroys survey and displays another" do
      expect_survey_is_replaced @docked_widget_survey, @inline_survey
    end
  end

  private

  def expect_survey_is_replaced(previous_survey, current_survey)
    expect(survey_widget.attribute("survey-widget-type")).to eq survey_widget_type(previous_survey)

    current_survey.live!

    driver.execute_script("pi('present', #{current_survey.id})")

    sleep 1 # wait for the original survey to be destroyed

    widget_container_elements = wait.until { driver.find_elements(id: "_pi_surveyWidgetContainer") }

    expect(widget_container_elements.length).to eq 1
    expect(survey_widget.attribute("survey-widget-type")).to eq survey_widget_type(current_survey)
  end
end
