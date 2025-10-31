# frozen_string_literal: true
class ScheduledReportSurveyLocaleGroup < ApplicationRecord
  belongs_to :scheduled_report
  belongs_to :survey_locale_group, foreign_key: :locale_group_id
  has_many :scheduled_report_surveys, dependent: :destroy
  has_many :surveys, through: :scheduled_report_surveys

  accepts_nested_attributes_for :scheduled_report_surveys, allow_destroy: true

  def name
    "#{survey_locale_group.name} (#{survey_locale_group.surveys.count})"
  end
end

# == Schema Information
#
# Table name: scheduled_report_survey_locale_groups
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  locale_group_id     :bigint           not null
#  scheduled_report_id :bigint           not null
#
# Indexes
#
#  index_scheduled_report_survey_locale_group_uniq  (scheduled_report_id,locale_group_id) UNIQUE
#
