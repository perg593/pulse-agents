# frozen_string_literal: true
class ScheduledReportSurvey < ActiveRecord::Base
  audited associated_with: :scheduled_report

  belongs_to :scheduled_report, optional: true
  belongs_to :scheduled_report_survey_locale_group, optional: true
  belongs_to :survey

  validate :validate_standalone_survey_association
  validate :validate_localized_survey_association

  attr_accessor :name

  private

  def validate_standalone_survey_association
    return if survey.localized?

    errors.add(:scheduled_report, 'scheduled report must exist') if scheduled_report.nil?
    errors.add(:scheduled_report_survey_locale_group, "can't be associated unless localized") if scheduled_report_survey_locale_group.present?
    errors.add(:survey, "survey must belong to same account as scheduled report") if survey.account_id != scheduled_report&.account_id
  end

  def validate_localized_survey_association
    return unless survey.localized?

    errors.add(:scheduled_report_survey_locale_group, 'scheduled_report_survey_locale_group must exist') if scheduled_report_survey_locale_group.nil?
    errors.add(:scheduled_report, "can't be associated unless standalone survey") if scheduled_report.present?

    # rubocop:disable Style/GuardClause
    # deal with it, rubocop
    if survey.account_id != scheduled_report_survey_locale_group&.survey_locale_group&.account&.id
      errors.add(:scheduled_report_survey_locale_group, "must belong to the same account as the survey")
    end
  end
end

# == Schema Information
#
# Table name: scheduled_report_surveys
#
#  id                                      :integer          not null, primary key
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  scheduled_report_id                     :integer
#  scheduled_report_survey_locale_group_id :bigint
#  survey_id                               :integer
#
# Indexes
#
#  index_scheduled_report_survey_on_locale_group_id       (scheduled_report_survey_locale_group_id)
#  index_scheduled_report_surveys_on_scheduled_report_id  (scheduled_report_id)
#
