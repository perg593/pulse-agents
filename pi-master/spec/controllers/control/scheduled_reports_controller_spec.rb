# frozen_string_literal: true
require 'spec_helper'

describe Control::ScheduledReportsController do
  before do
    @valid_start_date = Time.current.beginning_of_minute + 2.minutes
    ScheduledReport.delete_all
  end

  describe "ScheduledReport requirement" do
    describe "Missing record handling" do
      let(:endpoints) do
        [
          { verb: :get, url: :edit },
          { verb: :delete, url: :destroy },
          { verb: :patch, url: :update }
        ]
      end

      before do
        sign_in create(:user)
      end

      context "when attempting to access other accounts' reports" do
        before do
          @scheduled_report = create(:scheduled_report)
        end

        it "redirects to the survey dashboard" do
          endpoints.each { |endpoint| it_handles_missing_records(endpoint, id: @scheduled_report.id) }
        end
      end

      context "when reports don't exist" do
        before do
          ScheduledReport.destroy_all
        end

        it "redirects to the survey dashboard" do
          endpoints.each { |endpoint| it_handles_missing_records(endpoint) }
        end
      end
    end
  end

  describe "POST #create" do
    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }
    let(:valid_creation_params) do
      {
        scheduled_report: {
          name: 'scheduled_report',
          frequency: "weekly",
          date_range: "all_time",
          start_date: @valid_start_date,
          scheduled_report_surveys_attributes: {'0': {survey_id: survey.id}}
        }
      }
    end

    it "creates a scheduled report for reporting only users" do
      user = create(:reporting_only_user, account: account)
      user_can_create_report(user)
    end

    def user_can_create_report(user)
      sign_in user

      post :create, params: valid_creation_params

      expect(ScheduledReport.count).to eq 1
      it_redirects_to_index
    end

    it "does not create a scheduled report for a signed out user" do
      create(:user, account: account)

      post :create, params: valid_creation_params

      it_creates_no_record
      it_redirects_to_signin
    end

    context "with a full access user" do
      let(:user) { create(:user, account: account) }

      before do
        sign_in user
      end

      it "creates a scheduled report" do
        user_can_create_report(user)
      end

      it "accepts a start date specified in the user's time zone" do
        user_time_zone = ActiveSupport::TimeZone["America/Vancouver"]

        new_start_date = @valid_start_date.in_time_zone(user_time_zone)
        valid_creation_params[:scheduled_report][:start_date] = new_start_date

        post :create, params: valid_creation_params

        expect(ScheduledReport.count).to eq 1

        report = ScheduledReport.first
        expect(report.start_date).to eq(@valid_start_date)

        it_redirects_to_index
      end

      it "prohibits overly specific start dates" do
        new_start_date = Time.current.beginning_of_minute + 1.second
        valid_creation_params[:scheduled_report][:start_date] = new_start_date

        post :create, params: valid_creation_params

        it_creates_no_record
        expect(response).to have_http_status(:ok)
      end

      it "prohibits start dates in the past" do
        new_start_date = Time.current.beginning_of_minute - 1.day
        valid_creation_params[:scheduled_report][:start_date] = new_start_date

        post :create, params: valid_creation_params

        it_creates_no_record
        expect(response).to have_http_status(:ok)
      end

      it "allows nil start dates" do
        valid_creation_params[:scheduled_report][:start_date] = nil

        post :create, params: valid_creation_params
        expect(ScheduledReport.count).to eq 1

        report = ScheduledReport.first

        expect(report.start_date).to be_within(1).of(@valid_start_date)
        expect(report.send_next_report_at).to be_within(1).of(@valid_start_date)

        it_redirects_to_index
      end

      # Each record(ScheduledReportSurvey/ScheduledReportSurveyLocaleGroup) associated with a scheduled report represents one xlsx file.
      # Surveys within a group are associated with that group, and the group gets associated with a scheduled report because those surveys
      # are consolidated into one xlsx file.
      it "associates the surveys within a group to that group, not the scheduled report" do
        survey = create(:localized_survey)
        dup_survey = survey.duplicate.tap(&:save)
        dup_survey.add_to_localization_group(survey.survey_locale_group.id, 'test_lang_code')

        valid_creation_params[:scheduled_report][:scheduled_report_surveys_attributes] = nil
        valid_creation_params[:scheduled_report][:scheduled_report_survey_locale_groups_attributes] = {
          '0': {
            locale_group_id: survey.survey_locale_group.id,
            scheduled_report_surveys_attributes: {
              '0': {
                survey_id: survey.id
              }
            }
          }
        }

        post :create, params: valid_creation_params

        expect(ScheduledReport.count).to eq 1

        scheduled_report = ScheduledReport.first
        expect(scheduled_report.survey_locale_groups.count).to eq 1
        expect(scheduled_report.surveys.count).to be 0

        report_group = scheduled_report.survey_locale_groups.first
        expect(report_group).to eq survey.survey_locale_group
        expect(report_group.surveys).to contain_exactly(survey, dup_survey)
      end
    end
  end

  describe "PATCH #update" do
    before do
      @scheduled_report = create(:scheduled_report_with_account)
      @account = @scheduled_report.account
    end

    it "updates a scheduled report for reporting only users" do
      user = create(:reporting_only_user, account: @scheduled_report.account)
      user_can_update_report(user)
    end

    it "updates a scheduled report for full access users" do
      user = create(:user, account: @scheduled_report.account)
      user_can_update_report(user)
    end

    def user_can_update_report(user)
      sign_in user

      new_name = 'updated_scheduled_report'

      patch :update, params: { id: @scheduled_report.id, scheduled_report: { name: new_name }}

      it_redirects_to_index

      @scheduled_report.reload

      expect(@scheduled_report.name).to eq new_name
    end

    it "does not allow updates with start_date set to the past" do
      user = create(:user, account: @scheduled_report.account)
      sign_in user

      old_start_date = @scheduled_report.start_date
      old_send_next_report_at = @scheduled_report.send_next_report_at
      old_name = @scheduled_report.name

      new_name = 'updated_scheduled_report'
      patch :update, params: { id: @scheduled_report.id, scheduled_report: { name: new_name, start_date: @scheduled_report.start_date - 1.day }}

      assert_response 302
      assert_redirected_to edit_scheduled_report_path(@scheduled_report.id)

      @scheduled_report.reload

      expect(@scheduled_report.name).to eq old_name
      expect(@scheduled_report.start_date).to eq old_start_date
      expect(@scheduled_report.send_next_report_at).to eq old_send_next_report_at
    end

    it "allows updates to other columns when start_date is already in the past" do
      user = create(:user, account: @scheduled_report.account)
      sign_in user

      @scheduled_report.update_columns(start_date: @scheduled_report.start_date - 1.day)

      old_start_date = @scheduled_report.start_date
      old_send_next_report_at = @scheduled_report.send_next_report_at
      old_name = @scheduled_report.name

      new_name = 'updated_scheduled_report'
      patch :update, params: { id: @scheduled_report.id, scheduled_report: { name: new_name }}

      it_redirects_to_index

      @scheduled_report.reload

      expect(@scheduled_report.name).to eq new_name
      expect(@scheduled_report.start_date).to eq old_start_date
      expect(@scheduled_report.send_next_report_at).to eq old_send_next_report_at
    end

    it "does not change report delivery date when non-change is submitted" do
      user = create(:user, account: @scheduled_report.account)
      sign_in user

      original_start_date = Time.current.beginning_of_minute + 10.minutes
      original_send_next_report_at = original_start_date
      @scheduled_report.update(send_next_report_at: original_send_next_report_at)

      patch :update, params: { id: @scheduled_report.id, scheduled_report: { start_date: original_start_date }}

      it_redirects_to_index

      @scheduled_report.reload

      expect(@scheduled_report.start_date).to eq original_start_date
      expect(@scheduled_report.send_next_report_at).to eq original_send_next_report_at
    end

    it "does not change report delivery date when an overly specific time change is submitted" do
      user = create(:user, account: @scheduled_report.account)
      sign_in user

      original_start_date = Time.current.beginning_of_minute + 10.minutes
      original_send_next_report_at = original_start_date
      @scheduled_report.update(start_date: original_start_date)

      patch :update, params: { id: @scheduled_report.id, scheduled_report: { start_date: original_start_date + 1.seconds }}

      assert_response 302
      assert_redirected_to edit_scheduled_report_path(@scheduled_report.id)

      @scheduled_report.reload

      expect(@scheduled_report.start_date).to eq original_start_date
      expect(@scheduled_report.send_next_report_at).to eq original_send_next_report_at
    end

    it "converts the start and end times to UTC" do
      user = create(:user, account: @scheduled_report.account)
      sign_in user

      start_date_in_utc = (Time.current.beginning_of_minute + 2.minutes)
      start_date_in_est = start_date_in_utc.in_time_zone('EST')

      end_date_in_utc = (Time.current.beginning_of_minute + 12.minutes)
      end_date_in_est = end_date_in_utc.in_time_zone('EST')

      start_partial = start_date_in_est.strftime('%F %R %z')
      end_partial = end_date_in_est.strftime('%F %R %z')

      patch :update, params: { id: @scheduled_report.id, scheduled_report: { start_date: start_partial, end_date: end_partial}}

      it_redirects_to_index

      @scheduled_report.reload

      expect(@scheduled_report.start_date).to eq start_date_in_utc
      expect(@scheduled_report.end_date).to eq end_date_in_utc
    end

    it 'keeps pre-existing emails intact after an update has failed' do
      sign_in create(:user)

      scheduled_report_emails = @scheduled_report.scheduled_report_emails

      make_failing_call

      expect(scheduled_report_emails.reload.exists?).to be true
    end

    it 'keeps pre-existing emails intact after an update has succeeded' do
      sign_in create(:user)

      scheduled_report_emails = @scheduled_report.scheduled_report_emails

      make_passing_call

      expect(scheduled_report_emails.reload.exists?).to be true
    end

    it 'keeps pre-existing survey selections intact after an update has failed' do
      sign_in create(:user)

      @scheduled_report.scheduled_report_survey_locale_groups.delete_all
      @scheduled_report.scheduled_report_surveys.delete_all

      @scheduled_report.surveys << create(:survey, account: @account)
      @scheduled_report.survey_locale_groups << create(:survey_locale_group, account: @account)
      @scheduled_report.scheduled_report_survey_locale_groups.first.surveys << create(:localized_survey, account: @account)

      make_failing_call

      expect(@scheduled_report.surveys.reload.exists?).to be true
      expect(@scheduled_report.scheduled_report_survey_locale_groups.reload.exists?).to be true
      expect(@scheduled_report.scheduled_report_survey_locale_groups.first.scheduled_report_surveys.reload.exists?).to be true
    end

    it 'keeps pre-existing survey selections intact after an update has succeeded' do
      sign_in create(:user)

      @scheduled_report.scheduled_report_survey_locale_groups.delete_all
      @scheduled_report.scheduled_report_surveys.delete_all

      @scheduled_report.surveys << create(:survey, account: @account)
      @scheduled_report.survey_locale_groups << create(:survey_locale_group, account: @account)
      @scheduled_report.scheduled_report_survey_locale_groups.first.surveys << create(:localized_survey, account: @account)

      make_passing_call

      expect(@scheduled_report.surveys.reload.exists?).to be true
      expect(@scheduled_report.scheduled_report_survey_locale_groups.reload.exists?).to be true
      expect(@scheduled_report.scheduled_report_survey_locale_groups.first.scheduled_report_surveys.reload.exists?).to be true
    end
  end

  describe "pause/restart" do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }

    before do
      sign_in user
    end

    describe "PATCH #pause" do
      let(:scheduled_report) { create(:scheduled_report, account: account, paused: false) }

      it "pauses the scheduled report" do
        patch :pause, params: { id: scheduled_report.id }
        expect(scheduled_report.reload.paused).to be true
      end
    end

    describe "PATCH #restart" do
      let(:scheduled_report) { create(:scheduled_report, account: account, paused: true) }

      it "restarts the scheduled report" do
        patch :restart, params: { id: scheduled_report.id }
        expect(scheduled_report.reload.paused).to be false
      end

      it "updates next send date" do
        travel_to 1.week.from_now do
          patch :restart, params: { id: scheduled_report.id }
          expect(scheduled_report.reload.send_next_report_at.to_date).to eq Time.current.to_date
        end
      end
    end
  end

  # Hash inside :scheduled_report_emails_attributes is a bit unorthodox because of how the corresponding form object is constructed on the front end
  def make_failing_call
    patch :update, params: { id: @scheduled_report.id, scheduled_report: {
      scheduled_report_emails_attributes: { '0': { email: 'test@test.com' }, '1': { email: 'test@test.com' }} # email duplicates
    }}
  end

  def make_passing_call
    patch :update, params: { id: @scheduled_report.id, scheduled_report: { name: FFaker::Lorem.phrase } }
  end

  def it_creates_no_record
    expect(ScheduledReport.count).to eq 0
  end

  def it_redirects_to_index
    assert_response 302
    assert_redirected_to scheduled_reports_url
  end

  def it_redirects_to_signin
    assert_response 302
    assert_redirected_to sign_in_url
  end
end
