# frozen_string_literal: true
FactoryBot.define do
  factory :account do
    name { FFaker::Company.name }
    tag_js_version { '1.0.0' }

    factory :account_registered_with_qrvey do
      after(:create) do |account, _evaluator|
        create(:qrvey_user, account: account, qrvey_user_id: "qrvey_user_#{FFaker::Lorem.word}")
        create(:qrvey_application, qrvey_user: account.qrvey_user, qrvey_application_id: "qrvey_application_#{FFaker::Lorem.word}", shared: true)
      end
    end
  end
end
