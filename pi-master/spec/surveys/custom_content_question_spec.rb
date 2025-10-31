# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "custom content question" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:custom_content_question_class_name) { "_pi_question_custom_content_question" }
  let(:custom_content_question_element) { find_element({class: custom_content_question_class_name}) }

  let(:autoclose_enabled) { false }
  let(:autoclose_delay) { nil }

  let(:autoredirect_enabled) { false }
  let(:autoredirect_delay) { nil }
  let(:autoredirect_url) { nil }

  let(:non_fullscreen_widget) { find_element({id: "_pi_surveyWidget"}) }
  let(:fullscreen_widget) { find_element({id: "_pi_surveyWidgetCustom"}) }

  describe "when rendering" do
    let(:question) { create(:custom_content_question, survey: survey) }

    before do
      survey.questions << question
    end

    describe "autoclose" do
      subject { custom_content_question_element.displayed? }

      let(:question) { create(:custom_content_question, survey: survey, autoclose_enabled: autoclose_enabled, autoclose_delay: autoclose_delay) }

      before do
        driver.current_url # Waking up the lazy-loaded driver
        sleep(autoclose_delay ? autoclose_delay * 1.5 : 3)
      end

      context "when autoclose is enabled" do
        let(:autoclose_enabled) { true }

        context "when an autoclose delay is specified" do
          let(:autoclose_delay) { 3 }

          it { is_expected.to be false }
        end

        context "when no autoclose delay is specified" do
          it { is_expected.to be true }
        end
      end

      context "when autoclose is not enabled" do
        it { is_expected.to be true }
      end
    end

    describe "autoredirect" do
      subject { driver.current_url }

      let(:autoredirect_url) { "http://0.0.0.0" }
      let(:autoredirect_delay) { 3 }
      let(:question) { create(:custom_content_question, survey: survey, autoredirect_enabled: autoredirect_enabled, autoredirect_delay: autoredirect_delay, autoredirect_url: autoredirect_url) }

      before do
        @initial_url = driver.current_url # Waking up the lazy-loaded driver
        sleep(autoredirect_delay ? autoredirect_delay * 1.5 : 3)
      end

      context "when autoredirect is enabled" do
        let(:autoredirect_enabled) { true }

        context "when an autoredirect delay is specified" do
          it { is_expected.to eq "#{autoredirect_url}/" }
        end

        context "when no autoredirect delay is specified" do
          let(:autoredirect_delay) { nil }

          it { is_expected.to eq @initial_url }
        end
      end

      context "when autoredirect is not enabled" do
        it { is_expected.to eq @initial_url }
      end
    end

    describe "fullscreen" do
      let(:question) { create(:custom_content_question, survey: survey, fullscreen: fullscreen, background_color: background_color, opacity: opacity) }
      let(:fullscreen) { nil }
      let(:background_color) { nil }
      let(:opacity) { nil }

      context "when fullscreen mode is active" do
        let(:fullscreen) { true }

        before do
          driver.current_url # Waking up the lazy-loaded driver
          sleep(2) # fullscreen might take a couple seconds to get going
        end

        it "uses a different ID for the widget" do
          expect(fullscreen_widget).not_to be_nil
          expect(non_fullscreen_widget).to be_nil
        end

        describe "background_color" do
          subject { fullscreen_widget.style('background-color') }

          context "when background_color is specified" do
            let(:background_color) { "#0000FF" }

            it { is_expected.to eq "rgba(0, 0, 255, 1)" }
          end

          context "when background_color is not specified" do
            it { is_expected.to eq "rgba(255, 255, 255, 1)" }
          end
        end

        describe "opacity" do
          subject { fullscreen_widget.style('opacity') }

          context "when opacity is specified" do
            let(:opacity) { 30 }

            it { is_expected.to eq (opacity / 100.0).to_s }
          end

          context "when opacity is not specified" do
            it { is_expected.to eq "0.9" }
          end
        end
      end

      context "when fullscreen mode is inactive" do
        it "uses the default ID for the widget" do
          expect(fullscreen_widget).to be_nil
          expect(non_fullscreen_widget).not_to be_nil
        end
      end
    end
  end
end
