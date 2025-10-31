# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Block IEs' do
  let(:account) { create(:account) }

  let(:js) { "return window.PulseInsightsObject.logMessages;" }

  context 'when browser is not IE < 9' do
    it 'assigns window.PulseInsightsObject' do
      result = run_in_browser(js, html_test_page(account))
      result = result.join(', ')

      # ensuring javascript is being executed after a request passes the old IEs blocking function
      expect(result).to include('Set item in Local Storage pulse_insights_udid')
      expect(result).to include('Set item in Local Storage pi_visit_count')
      expect(result).to include('Set item in Local Storage pi_pageview_count')
      expect(result).to include('Set item in Local Storage pi_visit_track')
    end
  end

  context 'when browser is IE < 9' do
    it 'does not assign window.PulseInsightsObject' do
      # reset PI object after the condition setup
      conditon = "document.documentMode = 8; window.PulseInsightsObject = new window.PulseInsights(); "
      result = run_in_browser(conditon + js, html_test_page(account))
      result = result.join(', ')

      # making sure the executions after the old IEs blocking function aren't executed
      expect(result).to include('Old IE was blocked')
      expect(result).not_to include('Get item from Local Storage pi_pageview_count:')
      expect(result).not_to include('Get item from Local Storage pi_visit_track:')
    end
  end
end
