# frozen_string_literal: true
class ScheduledReportEmail < ActiveRecord::Base
  audited associated_with: :scheduled_report

  belongs_to :scheduled_report

  before_validation :strip_email

  validates :email, presence: true
  validates :email, email: true, uniqueness: { scope: :scheduled_report_id, message: 'is already registered' }

  private

  def strip_email
    email.strip!
  end
end

# == Schema Information
#
# Table name: scheduled_report_emails
#
#  id                  :integer          not null, primary key
#  email               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  scheduled_report_id :integer
#
# Indexes
#
#  index_scheduled_report_emails_on_email_and_scheduled_report_id  (email,scheduled_report_id) UNIQUE
#  index_scheduled_report_emails_on_scheduled_report_id            (scheduled_report_id)
#
