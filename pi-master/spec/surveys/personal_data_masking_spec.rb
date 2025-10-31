# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Personal data masking' do
  before do
    Account.delete_all
    Survey.delete_all
    Submission.delete_all
    Answer.delete_all
  end

  let(:account) { create(:account) }
  let!(:survey) { create(:survey_without_question, account: account) }
  let!(:question) { survey.questions.create(question_type: :free_text_question, content: 'can I help?', submit_label: 'Submit', error_text: 'error!') }

  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  let(:submit_button) { find_element({class: '_pi_free_text_question_submit_button'}) }
  let(:error_message) { find_element({class: '_pi_free_text_question_personal_data_alert'}).text }

  shared_examples "a data masking algorithm" do |feature_columns, masked_value|
    context "when the specific masking feature is enabled" do
      before do
        feature_columns.each { |column| account.personal_data_setting.update(column => true) }
      end

      context "when provided bad input" do
        before do
          send_input(masked_value)
        end

        it "displays error and disables the submit button" do
          expect(error_message).to eq(question.error_text)
          expect(submit_button.enabled?).to be false
        end
      end

      context "when provided NOT bad input" do
        before do
          send_input('foo')
        end

        it "displays no error and has the submit button stay enabled" do
          expect(error_message).to eq('')
          expect(submit_button.enabled?).to be true
        end
      end
    end
  end

  # Intermittent CI failure: https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1365
  # context "when the specific masking feature is not enabled" do
  #    context "when provided bad input" do
  #      before do
  #        send_input(masked_value)
  #      end
  #
  #      it "displays no error and has the submit button stay enabled" do
  #        expect(error_message).to eq('')
  #        expect(submit_button.enabled?).to be true
  #      end
  #    end
  #  end
  # end

  context "when masking is enabled" do
    before do
      account.personal_data_setting.update(masking_enabled: true)
    end

    context "when phone number masking is enabled" do
      it_behaves_like "a data masking algorithm", [:phone_number_masked], "123456789"
    end

    context "when e-mail masking is enabled" do
      it_behaves_like "a data masking algorithm", [:email_masked], FFaker::Internet.email
    end

    context "when both phone number and e-mail masking are enabled" do
      it_behaves_like "a data masking algorithm", [:phone_number_masked, :email_masked], FFaker::Internet.email
    end
  end

  private

  def send_input(text)
    find_element({class: '_pi_free_text_question_field'}).send_keys(text)
  end
end
