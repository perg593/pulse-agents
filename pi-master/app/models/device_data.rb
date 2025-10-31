# frozen_string_literal: true
class DeviceData < ActiveRecord::Base
  has_one :device
  has_one :account
end

# == Schema Information
#
# Table name: device_data
#
#  id          :integer          not null, primary key
#  device_data :jsonb
#  created_at  :datetime
#  updated_at  :datetime
#  account_id  :integer
#  device_id   :integer
#
# Indexes
#
#  index_device_data_on_account_id                (account_id)
#  index_device_data_on_account_id_and_device_id  (account_id,device_id)
#  index_device_data_on_device_id                 (device_id)
#
