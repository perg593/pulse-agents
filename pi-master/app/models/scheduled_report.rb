# frozen_string_literal: true
class ScheduledReport < ActiveRecord::Base
  audited associated_with: :account
  has_associated_audits

  belongs_to :account
  has_many :scheduled_report_emails, dependent: :destroy
  has_many :scheduled_report_surveys, dependent: :destroy
  has_many :surveys, through: :scheduled_report_surveys
  has_many :scheduled_report_survey_locale_groups, dependent: :destroy
  has_many :survey_locale_groups, through: :scheduled_report_survey_locale_groups

  enum frequency: { daily: 0, weekly: 1, biweekly: 2, monthly: 3 }
  enum date_range: { all_time: 0, one_month: 1, one_week: 2, one_day: 3, year_to_date: 4 }

  before_validation :set_default_start_date

  validate :start_date_cannot_be_in_the_past
  validate :start_date_cannot_be_too_specific
  validate :emails_cannnot_be_duplicated
  validate :surveys_or_groups_be_present
  validates_presence_of :account_id, :name, :frequency, :date_range, :start_date

  accepts_nested_attributes_for :scheduled_report_emails, :scheduled_report_surveys, :scheduled_report_survey_locale_groups, allow_destroy: true

  before_save :set_send_next_report_at
  after_save :destroy_redundant_survey_connections
  before_update :reset_send_next_report_at, if: :will_save_change_to_frequency?

  scope :due_for_processing, lambda {
    time = Time.current
    where("start_date <= ? AND (end_date IS NULL OR end_date >= ?) AND send_next_report_at <= ? AND paused = ?", time, time, time, false)
  }

  scope :stalled, -> { due_for_processing.where(in_progress: true).where("updated_at < ?", 10.minutes.ago) }
  scope :failed, -> { due_for_processing.where(in_progress: false).where("send_next_report_at <= ?", 11.minutes.ago) }

  def skip?
    skip_reasons.present?
  end

  def skip_reasons
    skip_reasons = []

    skip_reasons << [:already_in_progress, "Report is already marked as in progress"] if in_progress
    skip_reasons << [:ran_recently, "Report already ran within the last 24hrs"] if ran_recently?
    skip_reasons << [:no_emails, "Report has no associated e-mail addresses"] if scheduled_report_emails.count.zero?

    skip_reasons
  end

  def ran_recently?
    last_attempt_at.present? && last_attempt_at >= 23.hours.ago
  end

  def parse_date_range
    now = Time.current

    if all_time?
      nil
    elsif one_month?
      (now.beginning_of_day - 30.days)..(now.yesterday.end_of_day)
    elsif one_week?
      (now.beginning_of_day - 7.days)..(now.yesterday.end_of_day)
    elsif one_day?
      (now.yesterday.beginning_of_day)..(now.yesterday.end_of_day)
    elsif year_to_date?
      (now.beginning_of_year)..(now.yesterday.end_of_day)
    end
  end

  def update_send_next_report_at
    update!(send_next_report_at: upcoming_send_next_report_at)
  end

  private

  def destroy_redundant_survey_connections
    return unless all_surveys?

    scheduled_report_survey_locale_groups.destroy_all
    scheduled_report_surveys.destroy_all
  end

  def set_default_start_date
    return if start_date

    self.start_date = Time.current.beginning_of_minute + 2.minutes
  end

  def set_send_next_report_at
    return if start_date && !will_save_change_to_start_date?

    self.send_next_report_at = start_date
  end

  def reset_send_next_report_at
    return if in_progress? || will_save_change_to_send_next_report_at?

    self.send_next_report_at = Time.current.change(hour: send_next_report_at.hour, min: send_next_report_at.min)
    self.send_next_report_at = upcoming_send_next_report_at
  end

  def upcoming_send_next_report_at
    time_to_add = if daily?
      1.day
    elsif weekly?
      1.week
    elsif biweekly?
      2.weeks
    elsif monthly?
      1.month
    end

    upcoming_send_next_report_at = send_next_report_at + time_to_add

    end_date&.before?(upcoming_send_next_report_at) ? nil : upcoming_send_next_report_at
  end

  def start_date_cannot_be_in_the_past
    return unless start_date.present? && start_date < Time.current
    return unless will_save_change_to_start_date?

    errors.add(:start_date, "can't be in the past")
  end

  def start_date_cannot_be_too_specific
    return unless start_date.present? && start_date.sec.positive?

    errors.add(:start_date, "can't be too specific")
  end

  def emails_cannnot_be_duplicated
    # https://github.com/rails/rails/issues/20676
    #   Uniqueness check needs to consider objects that haven't been saved yet as well,
    #   but it's not possible for Rails to do so when using :accepts_nested_attributes_for,
    #   as it makes the autosaving of associations skip the validation step.
    emails = scheduled_report_emails.map(&:email) # :pluck doesn't pull data from unsaved nested attributes
    return if emails.size == emails.uniq.size

    errors.add(:scheduled_report_emails, "can't be duplicated")
  end

  def surveys_or_groups_be_present
    return if all_surveys? || scheduled_report_surveys.present? || scheduled_report_survey_locale_groups.present?

    errors.add(:base, "Surveys can't be empty!")
  end
end

# == Schema Information
#
# Table name: scheduled_reports
#
#  id                    :integer          not null, primary key
#  all_surveys           :boolean          default(FALSE)
#  date_range            :integer
#  end_date              :datetime
#  frequency             :integer
#  in_progress           :boolean          default(FALSE)
#  last_attempt_at       :datetime
#  name                  :string
#  paused                :boolean          default(FALSE)
#  send_next_report_at   :datetime
#  send_no_results_email :boolean          default(FALSE)
#  start_date            :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer
#
