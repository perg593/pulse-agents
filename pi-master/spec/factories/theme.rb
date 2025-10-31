# frozen_string_literal: true

FactoryBot.define do
  factory :theme do
    name { 'my_awesome_theme' }
    css  { ' ._pi_question _pi_question_single_choice_question { color: #ff0000; }' }
    account
  end

  factory :native_theme, class: 'Theme' do
    name { FFaker::Lorem.word }
    theme_type { :native }
    native_content { '{"background-color": "#FFFFFF"}' }
    account
  end
end
