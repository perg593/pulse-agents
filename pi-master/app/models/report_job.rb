# frozen_string_literal: true
class ReportJob < ActiveRecord::Base
  enum status: { created: 0, in_progress: 1, done: 2 }

  belongs_to :user
  belongs_to :survey, optional: true
  belongs_to :survey_locale_group, optional: true

  validates :current_user_email, presence: true
  validate :survey_xor_survey_locale_group
  validate :ownership_of_reportee

  def self.already_queued?(report_job)
    ReportJob.not_done.where(
      user_id: report_job.user_id, current_user_email: report_job.current_user_email,
      survey_id: report_job.survey_id, sudo_from_id: report_job.sudo_from_id,
      filters: report_job.filters, survey_locale_group_id: report_job.survey_locale_group_id
    ).exists?
  end

  def date_range
    return nil unless filters["date_range"]

    datetimes = filters["date_range"].split("..").map { |datetime_string| DateTime.parse(datetime_string) }
    datetimes.first..datetimes.last
  end

  def device_filter
    filters["device_filter"].present? ? Array.wrap(filters["device_filter"]) : nil
  end

  def market_ids
    filters["market_ids"].present? ? Array.wrap(filters["market_ids"]) : nil
  end

  def completion_url_filters
    filters["completion_urls"]&.map do |filter|
      filter.symbolize_keys!
      CompletionUrlFilter.new(filter[:matcher], filter[:value], cumulative: filter[:cumulative])
    end
  end

  def pageview_count_filter
    filter = filters["pageview_count"]&.symbolize_keys
    PageviewCountFilter.new(filter[:comparator], filter[:value]) if filter
  end

  def visit_count_filter
    filter = filters["visit_count"]&.symbolize_keys
    Filters::VisitCountFilter.new(filter[:comparator], filter[:value]) if filter
  end

  private

  def ownership_of_reportee
    return unless user

    if (survey && user.account != survey.account) ||
       (survey_locale_group && user.account != survey_locale_group.account)
      errors.add :report_job, "Access to this survey was denied."
    end
  end

  def survey_xor_survey_locale_group
    if survey.nil? && survey_locale_group.nil?
      errors.add :report_job, "Must have either a survey or a survey locale group"
    elsif survey.present? && survey_locale_group.present?
      errors.add :report_job, "Cannot have both a survey and survey locale group"
    end
  end
end

# == Schema Information
#
# Table name: report_jobs
#
#  id                     :integer          not null, primary key
#  current_user_email     :string
#  filters                :jsonb
#  report_url             :string
#  status                 :integer          default("created")
#  created_at             :datetime
#  updated_at             :datetime
#  sudo_from_id           :bigint
#  survey_id              :integer
#  survey_locale_group_id :bigint
#  user_id                :integer
#
# Indexes
#
#  index_report_jobs_on_survey_locale_group_id  (survey_locale_group_id)
#
