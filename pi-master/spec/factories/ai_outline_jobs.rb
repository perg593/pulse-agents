# frozen_string_literal: true
FactoryBot.define do
  factory :ai_outline_job do
    survey
    status { :pending }
    use_default_prompt { false }

    trait :pending do
      status { :pending }
    end

    trait :generating_outline do
      status { :generating_outline }
      started_at { Time.current }
    end

    trait :outline_completed do
      status { :outline_completed }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      outline_content { "# Survey Analysis Report\n\n## Executive Summary\nMock outline content for testing." }
    end

    trait :generating_gamma do
      status { :generating_gamma }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      outline_content { "# Survey Analysis Report\n\n## Executive Summary\nMock outline content for testing." }
      gamma_generation_id { "test_generation_#{SecureRandom.hex(4)}" }
      gamma_started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      outline_content { "# Survey Analysis Report\n\n## Executive Summary\nMock outline content for testing." }
      gamma_generation_id { "test_generation_#{SecureRandom.hex(4)}" }
      gamma_started_at { 5.minutes.ago }
      gamma_completed_at { Time.current }
      gamma_url { "https://gamma.app/docs/test-presentation" }
    end

    # Legacy traits for backward compatibility
    trait :in_progress do
      status { :generating_outline }
      started_at { Time.current }
    end

    trait :done do
      status { :outline_completed }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      outline_content { "# Survey Analysis Report\n\n## Executive Summary\nMock outline content for testing." }
    end

    trait :failed do
      status { :failed }
      started_at { 5.minutes.ago }
      completed_at { Time.current }
      error_message { 'Mock error message for testing' }
    end

    trait :with_prompt_template do
      prompt_template
    end

    trait :with_custom_prompt do
      prompt_text { 'Custom prompt text for testing' }
    end

    trait :with_default_prompt do
      use_default_prompt { true }
    end
  end
end
