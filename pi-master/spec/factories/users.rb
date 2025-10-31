# frozen_string_literal: true
FactoryBot.define do
  factory :user do
    first_name { "Jeremy" }
    last_name { "Bieger" }
    email { FFaker::Internet.email }
    level { :full }
    password { "Jeremy1234@" }
    password_confirmation { "Jeremy1234@" }

    account
  end

  factory :admin, class: 'User' do
    first_name { "Jeremy" }
    last_name { "Bieger" }
    email { FFaker::Internet.email }
    level { :full }
    password { "Jeremy1234@" }
    password_confirmation { "Jeremy1234@" }
    admin { true }

    account
  end

  factory :reporting_only_user, class: 'User' do
    first_name { "Jeremy" }
    last_name { "Bieger" }
    email { FFaker::Internet.email }
    level { :reporting }
    password { "Jeremy1234@" }
    password_confirmation { "Jeremy1234@" }

    account
  end
end
