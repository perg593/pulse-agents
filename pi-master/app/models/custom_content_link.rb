# frozen_string_literal: true

class CustomContentLink < ApplicationRecord
  belongs_to :custom_content_question, class_name: 'Question', foreign_key: :question_id
  has_many :clicks, class_name: 'CustomContentLinkClick'

  validates :link_url, presence: true
  validates :report_color, rgb: true # RGB color format. Only allows values like #000 and #ffffff

  scope :active, -> { where(archived_at: nil) }

  def click_count(filters: {})
    CustomContentLinkClick.filtered_clicks(clicks, filters: filters).count
  end

  def archive!
    update!(archived_at: Time.current)
  end
end

# == Schema Information
#
# Table name: custom_content_links
#
#  id              :bigint           not null, primary key
#  archived_at     :datetime
#  link_identifier :uuid             not null
#  link_text       :string
#  link_url        :string           not null
#  report_color    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  question_id     :bigint           not null
#
# Indexes
#
#  index_custom_content_links_on_question_id_and_link_identifier  (question_id,link_identifier)
#
