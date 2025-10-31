# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "Docked survey" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  describe "rendering" do
    describe "positioning" do
      let(:widget_container_xpath) { "/html/body/div[@id='_pi_surveyWidgetContainer']" }
      let(:widget_container) { find_element({xpath: widget_container_xpath}) }
      let(:widget) { find_element({xpath: "#{widget_container_xpath}/div[@id='_pi_surveyWidget']"}) }

      before do
        account.surveys << survey
        driver.current_url
        sleep(1)
      end

      context "when customized" do
        shared_examples "positionable" do |offset_side|
          let(:survey) { create(:survey, account: account, "#{offset_side}_position" => offset) }
          let(:offset_position) { widget.style(offset_side) }

          context "when px is set" do
            let(:offset) { "30px" }

            it "renders at the specified position" do
              expect_within_x_pixels(offset, offset_position)
            end
          end

          context "when % is set" do
            let(:offset) { "30%" }

            it "renders at the specified position" do
              widget_container_width = widget_container.style("width")
              offset_float = offset.delete("%").to_f

              expect_within_x_pixels(px_to_float(widget_container_width) * (offset_float / 100.0), offset_position)
            end
          end
        end

        it_behaves_like "positionable", "left"
        it_behaves_like "positionable", "right"
      end

      context "when not customized" do
        it "renders at the default position" do
          right_position = widget.style("right")
          widget_container_width = widget_container.style("width")

          expect_within_x_pixels(px_to_float(widget_container_width) * 0.10, right_position)
          expect(widget.style("bottom")).to eq "-3px"
          expect(widget.style("width")).to eq "300px"
          expect(widget.style("position")).to eq "fixed"
        end
      end
    end
  end

  def px_to_float(px_string)
    validator = /\A\d+(px)\z/
    if (px_string =~ validator).nil?
      RSpec::Expectations.fail_with("Bad format for px value. Expected '#px', but was #{px_string}")
    end

    px_string.delete("px").to_f
  end

  def expect_within_x_pixels(expected, actual)
    expected = px_to_float(expected) if expected.is_a? String
    actual = px_to_float(actual) if actual.is_a? String

    epsilon = 10

    expect(actual).to be_within(epsilon).of(expected)
  end
end
