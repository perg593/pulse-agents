# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "nps_question" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }
  let(:question_element) { find_element({class: "_pi_question"}) }
  let(:content) { FFaker::Lorem.phrase }

  it_behaves_like "additional question content", :nps_question
  it_behaves_like "additional text options", :nps_question
  it_behaves_like "answers per row", :nps_question
end
