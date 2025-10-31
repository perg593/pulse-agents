# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

# Also known as "overlay survey"
describe "Fullscreen survey" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account, survey_type: :fullscreen) }
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

      context "when a fullscreen margin is specified" do
        let(:survey) { create(:survey, account: account, survey_type: :fullscreen, fullscreen_margin: 10) }

        it "renders at the default position" do
          expect(widget.style("top")).to eq "0px"

          window_width = driver.manage.window.size.width

          expect(widget.style("width")).to eq "#{window_width - (window_width * 0.20).to_i}px" # i.e. full width - 20%
          expect(widget.style("margin")).to eq "#{(window_width * 0.10).to_i}px" # i.e. 10%

          expect(widget.style("height")).to match(/\d.*px/)
          expect(widget.style("height").delete('px').to_f).to be_within(5).of 41.5

          expect(widget.style("position")).to eq "fixed"
        end
      end

      context "when no fullscreen margin is specified" do
        it "renders at the default position" do
          window_width = driver.manage.window.size.width
          page_height = find_element({css: "html"}).style("height")

          expect(widget.style("top")).to eq "0px"
          expect(widget.style("width")).to eq "#{window_width}px" # i.e. 100%

          expect(widget.style("height")).to eq page_height # 100%
          expect(widget.style("position")).to eq "fixed"
        end
      end
    end
  end
end
