# frozen_string_literal: true

FactoryBot.define do
  factory :survey_overview_document do
    survey
    status { :pending }
    client_site_configuration { { target_url: 'https://example.com', cookie_selectors: [] } }

    trait :with_screenshot do
      after(:build) do |survey_overview_document|
        # Stub the file upload instead of using a real file
        allow(survey_overview_document.survey_editor_screenshot).to receive_messages(store!: true, url: 'https://example.com/test_image.png', present?: true)
      end
    end

    trait :completed do
      status { :completed }
      with_screenshot
    end

    trait :failed do
      status { :failed }
      failure_reason { "Test failure reason" }
    end
  end
end
