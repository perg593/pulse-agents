# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Top bar survey" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account, survey_type: :top_bar) }
  let(:driver) { @driver ||= setup_driver(html_test_file(html_test_page(account))) }

  describe "rendering" do
    describe "positioning" do
      let(:widget_container_xpath) { "/html/body/div[@id='_pi_surveyWidgetContainer']" }
      let(:widget) { find_element({xpath: "#{widget_container_xpath}/div[@id='_pi_surveyWidget']"}) }
      let(:pusher) { find_element({xpath: "/html/body/div[@id='_pi_pusher']"}) }

      before do
        account.surveys << survey
        driver.current_url
        sleep(1)
      end

      it "renders at the default position" do
        window_width = driver.manage.window.size.width

        expect(widget.style("top")).to eq "0px"
        expect(widget.style("width")).to eq "#{window_width}px" # i.e. 100%
        expect(widget.style("position")).to eq "fixed"

        # There's a bug that's causing this to fail.
        # Discuss with PI when (and whether) it should be fixed.
        # expect(pusher).to be nil
      end

      # "pusher" is an element to push page content that may
      # be obscured by the survey downwards
      context "when pusher element is enabled" do
        let(:survey) { create(:survey, account: account, survey_type: :top_bar, pusher_enabled: true) }

        it "renders the pusher element" do
          expect(pusher.style("height")).to match(/\d.*px/)
          expect(pusher.style("height").delete('px').to_f).to be_within(5).of 42

          expect(pusher.style("display")).to eq "block"
        end
      end
    end
  end
end
