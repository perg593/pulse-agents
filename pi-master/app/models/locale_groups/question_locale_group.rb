# frozen_string_literal: true

# Also known as a "Canonical Question", this ties together Questions across
# different Surveys, where each Survey represents a different market or locale.
#
# For example:
# "Feedback Survey EN" and "Feedback Survey FR" have one Question each:
# "Do you like Ekohe?" and "Aimes-tu Ekohe?". These questions both belong to the same
# QuestionLocaleGroup, which identifies them as being the same Question, just in different languages.
#
# Must be unique per SurveyLocaleGroup because other Surveys may have the same Question.
class QuestionLocaleGroup < LocaleGroup
  audited associated_with: :survey_locale_group

  belongs_to :survey_locale_group, foreign_key: :owner_record_id, inverse_of: :question_locale_groups
  has_many :questions
  has_many :possible_answer_locale_groups, foreign_key: :owner_record_id, inverse_of: :question_locale_group, dependent: :destroy
  has_many :answers, through: :questions

  has_one  :base_question, -> { order(:created_at) }, class_name: "Question"

  validates :name, presence: true

  accepts_nested_attributes_for :questions

  def find_account
    survey_locale_group.account
  end

  # ignore_multiple_type_dup: count answers for a multiple type question as one
  def answers_count(ignore_multiple_type_dup: false, filters: {})
    Answer.answers_count(answers, ignore_multiple_type_dup: ignore_multiple_type_dup, filters: filters)
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
