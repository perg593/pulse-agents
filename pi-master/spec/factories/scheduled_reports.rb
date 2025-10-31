# frozen_string_literal: true
FactoryBot.define do
  factory :scheduled_report, aliases: [:scheduled_report_with_surveys] do
    name { "Sample Scheduled Report" }
    frequency { 0 } # daily
    date_range { 0 } # all_time
    start_date { nil }
    account

    factory :scheduled_report_with_account do
      account factory: %i(account)
    end

    after(:build) do |scheduled_report, _evaluator|
      if scheduled_report.account && scheduled_report.surveys.empty?
        scheduled_report.surveys << create(:survey, account: scheduled_report.account)
      end
    end

    after(:create) do |scheduled_report, _evaluator|
      create(:scheduled_report_email, scheduled_report: scheduled_report)
    end
  end

  factory :scheduled_report_with_survey_locale_group, class: :scheduled_report do
    name { "Sample Scheduled Report" }
    frequency { 0 } # daily
    date_range { 0 } # all_time
    account

    after(:build) do |scheduled_report, _evaluator|
      survey = create(:survey, account: scheduled_report.account)
      survey.localize!
      srg = build(:scheduled_report_survey_locale_group, survey_locale_group: survey.survey_locale_group)
      srg.surveys << survey
      scheduled_report.scheduled_report_survey_locale_groups << srg
    end

    after(:create) do |scheduled_report, _evaluator|
      create(:scheduled_report_email, scheduled_report: scheduled_report)
    end
  end

  factory :scheduled_report_without_surveys, class: :scheduled_report do
    name { "Sample Scheduled Report" }
    frequency { 0 } # daily
    date_range { 0 } # all_time
    start_date { nil }
    account

    after(:create) do |scheduled_report, _evaluator|
      create(:scheduled_report_email, scheduled_report: scheduled_report)
    end
  end

  factory :scheduled_report_without_emails, class: :scheduled_report do
    name { "Sample Scheduled Report" }
    frequency { 0 } # daily
    date_range { 0 } # all_time
    account

    after(:build) do |scheduled_report, _evaluator|
      scheduled_report.surveys << create(:survey, account: scheduled_report.account) if scheduled_report.surveys.empty?
    end
  end
end
