# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Inline survey" do
  let(:account) { create(:account) }
  let(:inline_target_position) { nil }
  let(:inline_target_selector) { "#target_element" }
  let(:survey) { create(:inline_survey, account: account, inline_target_position: inline_target_position, inline_target_selector: inline_target_selector) }
  let(:widget_container) { find_element({xpath: widget_container_xpath}) }
  let(:widget) { find_element({id: "_pi_surveyWidget"}) }

  let(:driver) { @driver = setup_driver(html_test_file(inline_html_test_page(account))) }

  def inline_html_test_page(account)
    <<-html

    <html>
      <head>
        <title>Survey test page</title>
        #{account.tag_code}
      </head>
      <body>
        <div id='before_target_element'></div>
        <div id='target_element'>
          <div id='inside_target_element'></div>
        </div>
        <div id='after_target_element'></div>
        <div id='mobile_target_element'></div>
      </body>
    </html>

    html
  end

  shared_examples "inline target survey" do
    let(:widget_container_xpath) do
      {
        "above" => "/html/body/div[@id='target_element']/div[@id='_pi_surveyWidgetContainer']/following-sibling::div[@id='inside_target_element']",
        "below" => "/html/body/div[@id='target_element']/div[@id='_pi_surveyWidgetContainer']/preceding-sibling::div[@id='inside_target_element']",
        "before" => "/html/body/div[@id='_pi_surveyWidgetContainer']/following-sibling::div[@id='target_element']",
        "after" => "/html/body/div[@id='_pi_surveyWidgetContainer']/preceding-sibling::div[@id='target_element']"
      }[survey.inline_target_position]
    end

    it "renders where expected" do
      expect(widget_container).not_to be_nil

      expect(widget.style("position")).to eq "relative"
      expect(widget.style("width")).to eq widget_container.style("width") # i.e. 100% of parent
    end
  end

  describe "rendering" do
    describe "positioning" do
      before do
        account.surveys << survey
        driver.current_url
        sleep(1)
      end

      context "when position is above" do
        it_behaves_like "inline target survey" do
          let(:inline_target_position) { :above }
        end
      end

      context "when position is below" do
        it_behaves_like "inline target survey" do
          let(:inline_target_position) { :below }
        end
      end

      context "when position is before" do
        it_behaves_like "inline target survey" do
          let(:inline_target_position) { :before }
        end
      end

      context "when position is after" do
        it_behaves_like "inline target survey" do
          let(:inline_target_position) { :after }
        end
      end

      context "when no position is specified" do
        let(:survey) { create(:inline_survey, account: account, inline_target_selector: inline_target_selector) }

        it_behaves_like "inline target survey"
      end

      context "when mobile device" do
        let(:driver) { @driver = setup_driver(html_test_file(inline_html_test_page(account)), user_agent: "android mobile") }
        let(:survey) { create(:inline_survey, account: account, mobile_inline_target_selector: mobile_inline_target_selector, inline_target_selector: inline_target_selector) }
        let(:mobile_inline_target_selector) { nil }

        context "when mobile_inline_target_selector is specified" do
          let(:mobile_inline_target_selector) { "#mobile_target_element" }
          let(:widget_container_xpath) { "/html/body/div[@id='mobile_target_element']/div[@id='_pi_surveyWidgetContainer']" }

          it "renders the widget in the mobile target" do
            expect(widget_container).not_to be_nil
          end
        end

        context "when mobile_inline_target_selector is not specified" do
          let(:widget_container_xpath) { "/html/body/div[@id='target_element']/div[@id='_pi_surveyWidgetContainer']" }

          it "falls back to the inline_target_selector" do
            expect(widget_container).not_to be_nil
          end
        end
      end
    end
  end
end
