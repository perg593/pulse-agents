# frozen_string_literal: true
class PersonalDataSetting < ApplicationRecord
  belongs_to :account
end

# == Schema Information
#
# Table name: personal_data_settings
#
#  id                  :bigint           not null, primary key
#  email_masked        :boolean          default(FALSE), not null
#  masking_enabled     :boolean          default(FALSE), not null
#  phone_number_masked :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint
#
# Indexes
#
#  index_personal_data_settings_on_account_id  (account_id) UNIQUE
#
