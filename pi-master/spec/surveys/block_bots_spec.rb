# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe 'Block bots' do
  let(:account) { create(:account) }

  let(:js) { "return window.PulseInsightsObject.logMessages;" }

  context 'when userAgent is not a bot' do
    it 'assigns window.PulseInsightsObject' do
      result = run_in_browser(js, html_test_page(account), selenium_options: { user_agent: 'Mozilla/5.0 (Windows NT 6.1; WOW64)' })
      result = result.join(', ')

      # ensuring javascript is being executed after a request passes the old IEs blocking function
      expect(result).to include('Set item in Local Storage pulse_insights_udid')
      expect(result).to include('Set item in Local Storage pi_visit_count')
      expect(result).to include('Set item in Local Storage pi_pageview_count')
      expect(result).to include('Set item in Local Storage pi_visit_track')
    end
  end

  context 'when userAgent is Googlebot' do
    it 'does not assign window.PulseInsightsObject' do
      result = run_in_browser(js, html_test_page(account), selenium_options: { user_agent: 'Googlebot' })
      result = result.join(', ')

      # making sure the executions after the bots blocking function aren't executed
      expect(result).to include('Bot was blocked: Googlebot')
      expect(result).not_to include('Get item from Local Storage pi_pageview_count:')
      expect(result).not_to include('Get item from Local Storage pi_visit_track:')
    end
  end

  context 'when userAgent is baidu' do
    it 'does not assign window.PulseInsightsObject' do
      result = run_in_browser(js, html_test_page(account), selenium_options: { user_agent: 'baidu' })
      result = result.join(', ')

      # making sure the executions after the bots blocking function aren't executed
      expect(result).to include('Bot was blocked: baidu')
      expect(result).not_to include('Get item from Local Storage pi_pageview_count:')
      expect(result).not_to include('Get item from Local Storage pi_visit_track:')
    end
  end

  context 'when userAgent is yandex' do
    it 'does not assign window.PulseInsightsObject' do
      result = run_in_browser(js, html_test_page(account), selenium_options: { user_agent: 'yandex' })
      result = result.join(', ')

      # making sure the executions after the bots blocking function aren't executed
      expect(result).to include('Bot was blocked: yandex')
      expect(result).not_to include('Get item from Local Storage pi_pageview_count:')
      expect(result).not_to include('Get item from Local Storage pi_visit_track:')
    end
  end
end
