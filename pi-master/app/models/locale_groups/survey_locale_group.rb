# frozen_string_literal: true

# Also known as a "Canonical Survey", this ties together a group of Surveys,
# where each Survey represents a different market or locale.
#
# For example: "Feedback Survey EN" and "Feedback Survey FR".
#
# The base survey is a template for the others to follow.
class SurveyLocaleGroup < LocaleGroup
  include SurveyExtraAttrs::Stats

  audited associated_with: :account

  belongs_to :account, foreign_key: :owner_record_id, inverse_of: :survey_locale_groups
  has_many :surveys
  has_many :question_locale_groups, foreign_key: :owner_record_id, inverse_of: :survey_locale_group, dependent: :destroy
  has_many :impressions, through: :surveys
  has_many :viewed_impressions, through: :surveys
  has_many :submissions, through: :surveys
  has_many :answers, through: :surveys
  has_many :submission_caches, through: :surveys
  has_many :scheduled_report_survey_locale_groups, foreign_key: :locale_group_id, dependent: :destroy

  has_one  :base_survey, -> { order(:created_at) }, class_name: "Survey"

  before_destroy :unlocalize_surveys

  delegate :updated_by_name, to: :base_survey

  def base_questions
    question_locale_groups.map(&:base_question).sort_by(&:position)
  end

  def find_account
    account
  end

  def archived?
    surveys.pluck(:status).uniq == ['archived']
  end

  def report_stats(filters: {})
    stats = Submission.select(<<-SQL).where(survey_id: survey_ids_for_stats)
      COALESCE(SUM(1), 0) AS impression_count,
      COALESCE(SUM(CASE WHEN viewed_at IS NULL THEN 0 ELSE 1 END), 0) AS viewed_impression_count,
      COALESCE(SUM(CASE WHEN answers_count = 0 THEN 0 ELSE 1 END), 0) AS submission_count
    SQL

    Submission.filtered_submissions(stats, filters: filters)
  end

  private

  # used in SurveyExtraAttrs::Stats for duck typing
  def survey_ids_for_stats
    survey_ids
  end

  def unlocalize_surveys
    surveys.each(&:unlocalize!)
  end
end

# == Schema Information
#
# Table name: locale_groups
#
#  id              :bigint           not null, primary key
#  name            :string
#  report_color    :string
#  type            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  owner_record_id :integer
#
# Indexes
#
#  index_locale_groups_on_owner_record_id                    (owner_record_id)
#  index_locale_groups_on_type_and_owner_record_id           (type,owner_record_id)
#  index_locale_groups_on_type_and_owner_record_id_and_name  (type,owner_record_id,name) UNIQUE
#
