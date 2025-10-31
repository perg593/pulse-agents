# frozen_string_literal: true

class PageEvent < ApplicationRecord
  belongs_to :device
  belongs_to :account
end

# == Schema Information
#
# Table name: page_events
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  properties :jsonb
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  device_id  :bigint           not null
#
# Indexes
#
#  index_page_events_on_account_id  (account_id)
#  index_page_events_on_device_id   (device_id)
#  page_events_account_id_name_idx  (account_id,name)
#
