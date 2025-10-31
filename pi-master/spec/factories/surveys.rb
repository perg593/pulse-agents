# frozen_string_literal: true
FactoryBot.define do
  factory :survey do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    invitation { "Hello, want to take a survey?" }
    thank_you { "*Thank you* for your feedback!" }
    all_at_once_submit_label { "submit!" }
    all_at_once_error_text { "error!" }
    survey_type { :docked_widget }
    account
    after(:create) do |survey, _evaluator|
      create(:question, survey: survey, position: 0)
      create(:question, survey: survey, position: 1)
    end

    factory :survey_with_account do
      account factory: %i(account)
    end

    factory :localized_survey do
      language_code { "en_gb" }

      after(:create) do |survey, _evaluator|
        survey.reload
        survey.localize!
      end
    end

    factory :inline_survey do
      survey_type { :inline }
    end
  end

  factory :survey_with_one_question, class: 'Survey' do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    invitation { "Hello, want to take a survey?" }
    thank_you { "*Thank you* for your feedback!" }
    survey_type { :docked_widget }
    account
    after(:create) do |survey, _evaluator|
      create_list(:question, 1, survey: survey)
    end
  end

  factory :survey_with_one_free_question, class: 'Survey' do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    invitation { "Hello, want to take a survey?" }
    thank_you { "*Thank you* for your feedback!" }
    survey_type { :docked_widget }
    account
    after(:create) do |survey, _evaluator|
      create_list(:free_text_question, 1, content: FFaker::Lorem.word, survey: survey)
    end
  end

  factory :survey_with_one_multiple_question, class: 'Survey' do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    invitation { "Hello, want to take a survey?" }
    thank_you { "*Thank you* for your feedback!" }
    survey_type { :docked_widget }
    account
    after(:create) do |survey, _evaluator|
      create_list(:multiple_choices_question, 1, survey: survey)
    end
  end

  factory :survey_with_one_custom_question, class: 'Survey' do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    invitation { "Hello, want to take a survey?" }
    thank_you { "*Thank you* for your feedback!" }
    survey_type { :docked_widget }
    account
    after(:create) do |survey, _evaluator|
      create_list(:custom_content_question, 1, survey: survey)
    end
  end

  factory :survey_with_one_slider_question, class: 'Survey' do
    name { FFaker::Lorem.sentence }
    status { :live }
    account
    after(:create) do |survey, _evaluator|
      create_list(:slider_question, 1, survey: survey)
    end
  end

  factory :survey_without_question, class: 'Survey' do
    name { "Sample survey" }
    goal { 100 }
    status { 1 }
    width { 300 }
    survey_type { :docked_widget }
    account
  end
end
