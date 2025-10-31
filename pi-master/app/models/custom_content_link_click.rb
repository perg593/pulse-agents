# frozen_string_literal: true

# "client_key" and "custom_data" attributes exist in this model even though they already do in Submission because
# a command like "pi('custom_data', someData);" could be called through a client's custom JS or callbacks before/after
# a custom content question's appearance which makes those attributes different from the initial/final values stored in Submission.
class CustomContentLinkClick < ApplicationRecord
  belongs_to :submission
  belongs_to :custom_content_link

  def self.filtered_clicks(clicks, filters: {})
    return clicks unless filters.present?

    filters.each do |field, value|
      clicks = case field
      when :date_range
        clicks.where(created_at: value)
      when :device_types
        clicks.joins(:submission).where(submissions: { device_type: value })
      when :completion_urls
        clicks.joins(:submission).where(CompletionUrlFilter.combined_sql(value))
      when :pageview_count, :visit_count
        clicks.joins(:submission).where(value.to_sql)
      else
        Rails.logger.info "Unrecognized filter #{field}"
        clicks
      end
    end

    clicks
  end
end

# == Schema Information
#
# Table name: custom_content_link_clicks
#
#  id                     :bigint           not null, primary key
#  client_key             :string
#  custom_data            :jsonb
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  custom_content_link_id :bigint
#  submission_id          :bigint
#
# Indexes
#
#  index_custom_content_link_clicks_on_custom_content_link_id  (custom_content_link_id)
#  index_custom_content_link_clicks_on_submission_id           (submission_id)
#
