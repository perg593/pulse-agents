# frozen_string_literal: true
class Device < ActiveRecord::Base
  has_many :submissions
  has_many :device_datas
  has_many :page_events

  validates :udid, presence: true, length: 36..36
  validates :udid, udid: true

  def eligible_for_refire_for_survey?(survey)
    return false unless survey.refire_enabled
    return true if survey.refire_time.zero?

    refire_threshold = survey.refire_time.send(survey.refire_time_period).ago
    refire_threshold >= submissions.order(:created_at).last.created_at
  end

  def hit_frequency_cap_for_survey?(survey)
    return false unless survey.frequency_cap_active?

    # TODO: Validate this in the model, not here
    return false unless %w(minutes hours days).include?(account.frequency_cap_type)

    frequency_range = account.frequency_cap_duration.send(account.frequency_cap_type).ago
    submissions_in_range = submissions.where("created_at >= ?", frequency_range)

    submissions_in_range.count >= account.frequency_cap_limit
  end
end

# == Schema Information
#
# Table name: devices
#
#  id         :integer          not null, primary key
#  client_key :string
#  udid       :string(255)
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_devices_on_client_key  (client_key)
#  index_devices_on_udid        (udid)
#
