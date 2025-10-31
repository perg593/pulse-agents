# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "tag.js" do
  let(:account) { create(:account, tag_js_version: tag_js_version) }

  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  before do
    create(:survey, account: account)
  end

  describe "Versions" do
    %w(1.0.0 1.0.1 1.0.2).each do |tag_js_version|
      context "with #{tag_js_version}" do
        let(:tag_js_version) { tag_js_version }

        it 'renders the survey' do
          expect(widget_container.present?).to be true
        end
      end
    end
  end

  def widget_container
    find_element({ xpath: "//div[@class='_pi_widgetContentContainer']" })
  end
end
