# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Bottom bar survey" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account, survey_type: :bottom_bar) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  describe "rendering" do
    describe "positioning" do
      let(:widget_container_xpath) { "/html/body/div[@id='_pi_surveyWidgetContainer']" }
      let(:widget) { find_element({xpath: "#{widget_container_xpath}/div[@id='_pi_surveyWidget']"}) }

      before do
        account.surveys << survey
        driver.current_url
        sleep(1)
      end

      it "renders at the default position" do
        window_width = driver.manage.window.size.width

        expect(widget.style("bottom")).to eq "0px"
        expect(widget.style("width")).to eq "#{window_width}px" # i.e. 100%
        expect(widget.style("position")).to eq "fixed"
      end
    end
  end
end
