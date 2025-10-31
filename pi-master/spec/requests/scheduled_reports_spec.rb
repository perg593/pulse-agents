# frozen_string_literal: true
require 'spec_helper'

describe 'ScheduledReport' do
  let(:user) { create(:user) }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: user.password } }
  end

  it 'displays surveys and groups in the 4th column' do
    scheduled_report = create(:scheduled_report, account: user.account)
    scheduled_report_with_group = create(:scheduled_report_with_survey_locale_group, account: user.account)

    get "/scheduled_reports"

    assert_select '.scheduled-survey-name[1] > td[4] > a', text: scheduled_report.surveys.first.name
    assert_select '.scheduled-survey-name[2] > td[4] > a', text: scheduled_report_with_group.survey_locale_groups.first.name
  end

  context 'when it has failed to save' do
    it 'displays the previous input' do
      scheduled_report_name = FFaker::Lorem.word

      # This will intentionally fail due to the start date being in the past
      post scheduled_reports_path, params: { scheduled_report: { name: scheduled_report_name, start_date: Time.new(2000) } }

      expect(response).to render_template :new
      expect(response.body).to include scheduled_report_name # Can't use assert_select because the page is rendered by React
    end
  end
end
