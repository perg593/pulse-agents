# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReportPresenter do
  let(:account) { create(:account) }
  let(:scheduled_report) { ScheduledReport.new }
  let(:presenter) { described_class.new(account, scheduled_report) }

  it "can be instantiated" do
    expect(presenter.nil?).to be false
  end

  it "provides date_range_options" do
    date_range_options = presenter.date_range_options

    expect(date_range_options.class).to eq Array

    # Keeping this independent of simple_enum to make that gem's removal easier
    expected_date_range_options = [
      ["Previous Month", :one_month],
      ["Previous Week", :one_week],
      ["Previous Day", :one_day],
      ["Year to date", :year_to_date],
      ["All Time", :all_time]
    ]

    expect(date_range_options.length).to eq expected_date_range_options.length

    date_range_options.each_with_index do |option, i|
      expect(option.keys).to match_array(%i(label value))
      expect(option[:label]).to eq expected_date_range_options[i][0]
      expect(option[:value]).to eq expected_date_range_options[i][1]
    end
  end

  describe "email_options" do
    context "when no scheduled report is provided" do
      before do
        3.times { |_| create(:user, account: account) }
      end

      it "provides email addresses for all users of the account" do
        email_options = presenter.email_options

        expect(email_options.class).to eq Array

        expect(email_options.length).to eq account.users.count
        expected_email_addresses = account.users.pluck(:email).sort

        email_options.each_with_index do |option, i|
          expect(option.keys).to match_array(%i(label email checked id))
          email_address = expected_email_addresses[i]

          expect(option[:id]).to be_nil
          expect(option[:label]).to eq email_address
          expect(option[:email]).to eq email_address
          expect(option[:checked]).to be false
        end
      end
    end

    context "when a scheduled report is provided" do
      let(:scheduled_report) { create(:scheduled_report, account: account) }
      let(:presenter) { described_class.new(account, scheduled_report) }

      before do
        # user whose e-mail address is used by no scheduled report
        create(:user, account: account)

        # e-mail address used by a scheduled report but associated with no user
        create(:scheduled_report_email, scheduled_report: scheduled_report)

        # e-mail address used by a scheduled report and associated with a user
        create(:scheduled_report_email, scheduled_report: scheduled_report, email: create(:user, account: account).email)
      end

      it "provides email addresses for all users of the account along with e-mail addresses of non-users" do
        email_options = presenter.email_options

        expect(email_options.class).to eq Array

        email_addresses = (scheduled_report.scheduled_report_emails.pluck(:email) + account.users.pluck(:email)).uniq.sort
        expected_scheduled_report_emails = email_addresses.map do |email_address|
          ScheduledReportEmail.find_or_initialize_by(email: email_address, scheduled_report: scheduled_report)
        end

        expect(email_options.length).to eq(expected_scheduled_report_emails.length)

        email_options.each_with_index do |option, i|
          expected_scheduled_report_email = expected_scheduled_report_emails[i]

          expect(option.keys).to match_array(%i(label email checked id))

          expect(option[:id]).to eq expected_scheduled_report_email.id if expected_scheduled_report_email.persisted?

          email_address = expected_scheduled_report_email.email

          expect(option[:label]).to eq email_address
          expect(option[:email]).to eq email_address
          expect(option[:checked]).to eq expected_scheduled_report_email.persisted?
        end
      end
    end
  end

  it "provides frequency_options" do
    frequency_options = presenter.frequency_options

    expect(frequency_options.class).to eq Array

    # Keeping this independent of simple_enum to make that gem's removal easier
    expected_frequency_options = [
      %w(Daily daily),
      %w(Weekly weekly),
      %w(Biweekly biweekly),
      %w(Monthly monthly)
    ]

    expect(frequency_options.length).to eq expected_frequency_options.length

    frequency_options.each_with_index do |option, i|
      expect(option.keys).to match_array(%i(label value))

      expect(option[:label]).to eq expected_frequency_options[i][0]
      expect(option[:value]).to eq expected_frequency_options[i][1]
    end
  end

  describe "#survey_locale_group_options" do
    before do
      3.times do |_|
        base_survey = create(:localized_survey, account: account, name: "#{FFaker::Lorem.word} localized survey")
        child_survey = create(:survey, account: account, name: "#{FFaker::Lorem.word} survey")
        survey_locale_group_id = base_survey.survey_locale_group_id

        3.times do |_|
          child_survey.add_to_localization_group(survey_locale_group_id, FFaker::Lorem.word)
        end
      end
    end

    context "when a scheduled_report is provided" do
      let(:scheduled_report) { create(:scheduled_report) }
      let(:presenter) { described_class.new(account, scheduled_report) }

      before do
        survey_locale_group = SurveyLocaleGroup.all.order(:id)[0]

        scheduled_report_survey_locale_group = create(:scheduled_report_survey_locale_group, scheduled_report: scheduled_report,
                                                      survey_locale_group: survey_locale_group)

        create(:scheduled_report_survey, survey: survey_locale_group.surveys[0],
               scheduled_report_survey_locale_group_id: scheduled_report_survey_locale_group.id)

        survey_locale_group = SurveyLocaleGroup.all.order(:id)[1]

        scheduled_report_survey_locale_group = create(:scheduled_report_survey_locale_group, scheduled_report: scheduled_report,
                                                      survey_locale_group: survey_locale_group)

        create(:scheduled_report_survey, survey: survey_locale_group.surveys.order(:id)[0],
               scheduled_report_survey_locale_group_id: scheduled_report_survey_locale_group.id)
        create(:scheduled_report_survey, survey: survey_locale_group.surveys.order(:id)[1],
               scheduled_report_survey_locale_group_id: scheduled_report_survey_locale_group.id)
      end

      it "provides survey_locale_group_options" do
        survey_locale_group_options = presenter.survey_locale_group_options

        expect(survey_locale_group_options.class).to eq Array

        expected_survey_locale_groups = SurveyLocaleGroup.where(account: account).order(:name)
        expect(survey_locale_group_options.length).to eq expected_survey_locale_groups.count

        survey_locale_group_options.each_with_index do |survey_locale_group_option, i|
          survey_locale_group = expected_survey_locale_groups[i]

          expect(survey_locale_group_option.keys).to match_array(%i(id surveyLocaleGroupId label initiallyChecked surveys))

          scheduled_report_survey_locale_group = scheduled_report.scheduled_report_survey_locale_groups.find_by(locale_group_id: survey_locale_group.id)

          expect(survey_locale_group_option[:id]).to eq scheduled_report_survey_locale_group&.id
          expect(survey_locale_group_option[:surveyLocaleGroupId]).to eq survey_locale_group.id
          expect(survey_locale_group_option[:label]).to eq survey_locale_group.name
          expect(survey_locale_group_option[:initiallyChecked]).to eq scheduled_report.survey_locale_groups.include?(survey_locale_group)

          expect(survey_locale_group_option[:initiallyChecked]).to eq(scheduled_report.survey_locale_groups.where(id: survey_locale_group.id).exists?)

          expect(survey_locale_group_option[:surveys].class).to eq Array
          expected_surveys = survey_locale_group.surveys.order(:name)
          expect(survey_locale_group_option[:surveys].length).to eq expected_surveys.count

          survey_locale_group_option[:surveys].each_with_index do |survey_option, j|
            survey_structure_is_correct(
              survey_option,
              expected_surveys[j],
              scheduled_report: scheduled_report,
              scheduled_report_survey_locale_group: scheduled_report_survey_locale_group
            )
          end
        end
      end
    end

    context "when no scheduled_report is provided" do
      it "provides survey_locale_group_options" do
        survey_locale_group_options = presenter.survey_locale_group_options

        expect(survey_locale_group_options.class).to eq Array

        expected_survey_locale_groups = SurveyLocaleGroup.where(account: account).order(:name)
        expect(survey_locale_group_options.length).to eq expected_survey_locale_groups.count

        survey_locale_group_options.each_with_index do |survey_locale_group_option, i|
          survey_locale_group = expected_survey_locale_groups[i]

          expect(survey_locale_group_option.keys).to match_array(%i(id surveyLocaleGroupId label initiallyChecked surveys))

          expect(survey_locale_group_option[:id]).to be_nil
          expect(survey_locale_group_option[:surveyLocaleGroupId]).to eq survey_locale_group.id
          expect(survey_locale_group_option[:label]).to eq survey_locale_group.name
          expect(survey_locale_group_option[:initiallyChecked]).to be false

          expect(survey_locale_group_option[:surveys].class).to eq Array
          expected_surveys = survey_locale_group.surveys.order(:name)
          expect(survey_locale_group_option[:surveys].length).to eq expected_surveys.count

          survey_locale_group_option[:surveys].each_with_index do |survey_option, j|
            survey_structure_is_correct(survey_option, expected_surveys[j])
          end
        end
      end
    end
  end

  def survey_structure_is_correct(option, survey, scheduled_report: nil, scheduled_report_survey_locale_group: nil)
    expect(option.keys).to match_array(%i(scheduledReportSurveyId surveyId label initiallyChecked))

    scheduled_report_survey_id = if scheduled_report
      parent = scheduled_report_survey_locale_group || scheduled_report
      parent.scheduled_report_surveys.find_by(survey_id: survey.id)&.id
    end

    expect(option[:scheduledReportSurveyId]).to eq(scheduled_report_survey_id)
    expect(option[:surveyId]).to eq(survey.id)
    expect(option[:label]).to eq(survey.name)

    checked = if scheduled_report
      scheduled_report.surveys.include?(survey) ||
        scheduled_report.scheduled_report_survey_locale_groups.any? { |slg| slg.surveys.include? survey }
    else
      false
    end

    expect(option[:initiallyChecked]).to eq(checked)
  end

  describe "#survey_options" do
    before do
      2.times do |_|
        create(:survey, account: account, name: "#{FFaker::Lorem.word} survey")
      end

      create(:localized_survey, account: account)
    end

    context "when a scheduled_report is provided" do
      let(:scheduled_report) { create(:scheduled_report, account: account) }
      let(:presenter) { described_class.new(account, scheduled_report) }

      it "provides survey_options" do
        survey_options = presenter.survey_options

        expect(survey_options.class).to eq Array

        surveys = account.surveys.where(survey_locale_group_id: nil).order(:name)
        expect(survey_options.length).to eq surveys.count

        survey_options.each_with_index do |option, i|
          survey_structure_is_correct(option, surveys[i], scheduled_report: scheduled_report)
        end
      end
    end

    context "when no scheduled_report is provided" do
      it "provides survey_options" do
        survey_options = presenter.survey_options

        expect(survey_options.class).to eq Array

        surveys = account.surveys.where(survey_locale_group_id: nil).order(:name)
        expect(survey_options.length).to eq surveys.count

        survey_options.each_with_index do |option, i|
          survey_structure_is_correct(option, surveys[i])
        end
      end
    end
  end

  describe "#form_attributes" do
    def it_has_accurate_form_attributes(scheduled_report, result)
      edit_page = scheduled_report.persisted?

      expected_result = {
        dateRangeOptions: presenter.date_range_options,
        emailOptions: presenter.email_options,
        frequencyOptions: presenter.frequency_options,
        surveyLocaleGroupOptions: presenter.survey_locale_group_options,
        surveyOptions: presenter.survey_options,
        name: scheduled_report.name,
        frequency: scheduled_report.frequency.to_s,
        dataRange: scheduled_report.date_range.to_s,
        startDate: scheduled_report.start_date.to_i * 1000,
        endDate: scheduled_report.end_date.to_i * 1000,
        formUrl: (edit_page ? "/scheduled_reports/#{scheduled_report.id}" : "/scheduled_reports"),
        formMethod: (edit_page ? "PATCH" : "POST"),
        allSurveys: scheduled_report.all_surveys,
        sendNoResultsEmail: false
      }

      expect(expected_result).to eq result
    end

    context "when a scheduled report is provided" do
      it "returns accurate form attributes" do
        result = presenter.form_attributes

        it_has_accurate_form_attributes(scheduled_report, result)
      end
    end

    context "when no scheduled report is provided" do
      let(:scheduled_report) { ScheduledReport.new }
      let(:presenter) { described_class.new(account, scheduled_report) }

      it "returns accurate form attributes" do
        result = presenter.form_attributes

        it_has_accurate_form_attributes(scheduled_report, result)
      end
    end
  end
end
