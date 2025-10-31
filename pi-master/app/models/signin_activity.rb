# frozen_string_literal: true

# https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2809
#  This model was originally created to send platform usage information to Vitally.
#  Now that the team has migrated from Vitally to Coda, this model is no longer used by the application.
#  However, we will continue capturing data and keep the code for Coda.
class SigninActivity < ApplicationRecord
  belongs_to :account
  belongs_to :sudoer, class_name: 'User', optional: true
  belongs_to :user

  scope :for_external_teams, -> { joins(:user).where(sudoer_id: nil).where("users.email NOT LIKE '%@pulseinsights.com'") }
end

# == Schema Information
#
# Table name: signin_activities
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  sudoer_id  :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_signin_activities_on_account_id  (account_id)
#  index_signin_activities_on_sudoer_id   (sudoer_id)
#  index_signin_activities_on_user_id     (user_id)
#
