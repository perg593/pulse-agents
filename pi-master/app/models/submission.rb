# frozen_string_literal: true
class Submission < ApplicationRecord
  VALID_DEVICE_TYPES = %w(desktop tablet mobile native_mobile email).freeze

  belongs_to :survey
  belongs_to :device
  has_many :answers, dependent: :nullify
  has_many :custom_content_link_clicks, dependent: :destroy

  before_create :save_date
  before_destroy :recalculate_survey_answers_count
  after_destroy :update_cached_counts

  scope :viewed, -> { where.not(viewed_at: nil) }
  scope :answered, -> { where('answers_count > 0') }

  enum mobile_type: %i(ios android)

  attribute :answers_count, :integer, default: 0

  def os
    user_agent_obj.os
  end

  def browser
    user_agent_obj.browser
  end

  def browser_version
    user_agent_obj.version
  end

  def channel
    case device_type
    when 'email'
      'Email'
    when 'native_mobile'
      'Native SDK'
    when 'desktop', 'mobile', 'tablet'
      'Browser'
    else
      'Direct Submission/Link'
    end
  end

  def user_agent_obj
    UserAgent.parse(self[:user_agent])
  end

  def previous_surveys
    Survey.joins(:impressions).where('submissions.device_id = ? AND submissions.created_at < ?', device_id, created_at).count
  end

  def self.filtered_submissions(submission_scope, filters: {})
    return submission_scope unless filters.present?

    filters.each do |field, value|
      submission_scope = case field
      when :date_range
        submission_scope.where(created_at: value)
      when :device_types
        submission_scope.where(device_type: value)
      when :market_ids
        submission_scope.where(survey_id: value)
      when :completion_urls
        submission_scope.where(CompletionUrlFilter.combined_sql(value))
      when :possible_answer_id
        submission_ids = Answer.where(possible_answer_id: value).pluck(:submission_id)
        submission_scope.where(id: submission_ids)
      when :pageview_count, :visit_count
        submission_scope.where(value.to_sql)
      else
        Rails.logger.info "Unrecognized filter #{field}"
        submission_scope
      end
    end

    submission_scope
  end

  def self.submission_possible_answer_id_filter_sql(possible_answer_id)
    return true unless possible_answer_id

    submission_ids = Answer.where(possible_answer_id: possible_answer_id).pluck(:submission_id)
    return true if submission_ids.empty?

    filter_string = submission_ids.join(",")

    <<-SQL
        submissions.id IN (#{filter_string})
    SQL
  end

  def self.submissions_device_filter_sql(device_filters)
    return true unless device_filters

    filter_string = device_filters.map { |device_type| "'#{device_type}'" }.join(",")

    <<-SQL
        submissions.device_type IN (#{filter_string})
    SQL
  end

  def self.submissions_completion_url_filter_sql(completion_url_filters)
    return true unless completion_url_filters

    CompletionUrlFilter.combined_sql(completion_url_filters)
  end

  # TODO: Merge this with SQLHelpers#date_range_filter
  def self.submissions_date_filter_sql(date_range)
    return true unless date_range

    <<-SQL
        submissions.created_at BETWEEN '#{PG::Connection.escape(date_range.first.utc.to_s)}' AND '#{PG::Connection.escape(date_range.last.utc.to_s)}'
    SQL
  end

  def self.submissions_pageview_count_filter_sql(pageview_count_filter)
    return true unless pageview_count_filter

    pageview_count_filter.to_sql
  end

  def self.submissions_visit_count_filter_sql(visit_count_filter)
    return true unless visit_count_filter

    visit_count_filter.to_sql
  end

  def self.submissions_id_filter_sql(submission_id)
    return true unless submission_id

    <<-SQL
        submissions.id = #{submission_id}
    SQL
  end

  private

  def save_date
    created_date = Date.today
  end

  def recalculate_survey_answers_count
    new_survey_answers_count = survey.submissions.count

    survey.survey_stat.update(answers_count: new_survey_answers_count)
  end

  def update_cached_counts
    SurveySubmissionCache.remove_submission_record(self)
  end
end

# == Schema Information
#
# Table name: submissions
#
#  id                    :integer          not null, primary key
#  answers_count         :integer
#  client_key            :string
#  closed_by_user        :boolean          default(FALSE)
#  created_date          :date
#  custom_data           :json
#  device_type           :string
#  ip_address            :string(255)
#  mobile_days_installed :integer
#  mobile_launch_times   :integer
#  mobile_type           :integer
#  pageview_count        :integer
#  pseudo_event          :string
#  udid                  :string
#  url                   :string(10000)
#  user_agent            :string(10000)
#  view_name             :string
#  viewed_at             :datetime
#  visit_count           :integer
#  created_at            :datetime
#  device_id             :integer
#  survey_id             :integer
#
# Indexes
#
#  index_submissions_on_client_key                 (client_key)
#  index_submissions_on_created_at                 (created_at)
#  index_submissions_on_device_id                  (device_id)
#  index_submissions_on_survey_id                  (survey_id)
#  index_submissions_on_survey_id_with_answers     (survey_id,id) WHERE (answers_count > 0)
#  index_submissions_on_survey_id_with_created_at  (survey_id,created_at) WHERE (answers_count > 0)
#  index_submissions_on_survey_id_with_device_id   (survey_id,device_id)
#  index_submissions_on_survey_id_with_id          (survey_id,id)
#  index_submissions_on_udid                       (udid)
#  index_submissions_on_viewed_at                  (viewed_at)
#  submissions_survey_id_created_at_idx            (survey_id,created_at)
#  submissions_survey_id_idx                       (survey_id) WHERE (viewed_at IS NOT NULL)
#
