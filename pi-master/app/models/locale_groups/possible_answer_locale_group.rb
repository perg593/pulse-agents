# frozen_string_literal: true

# Also known as a "Canonical PossibleAnswer", this ties together PossibleAnswers
# across different Surveys, where each Survey represents a different market or locale.
#
# For example:
# "Feedback Survey EN" and "Feedback Survey FR" have one question each:
# "Do you like Ekohe?" and "Aimes-tu Ekohe?", which have PossibleAnswers
# "Yes", "No"; "Oui", "Non".
#
# PossibleAnswerLocaleGroup identifies "Yes" and "Oui", and "No" and "Non" as being the same PossibleAnswer, just in different languages.
# Must be unique per QuestionLocaleGroup because other Questions may have "yes/no" PossibleAnswers.
class PossibleAnswerLocaleGroup < LocaleGroup
  include Numerable

  audited associated_with: :question_locale_group

  belongs_to :question_locale_group, foreign_key: :owner_record_id, inverse_of: :possible_answer_locale_groups
  has_many :possible_answers
  has_many :answers, through: :possible_answers

  has_one  :base_possible_answer, -> { order(:created_at) }, class_name: "PossibleAnswer"

  validates :name, presence: true
  validates :report_color, rgb: true # RGB color format. Only allows values like #000 and #ffffff

  accepts_nested_attributes_for :possible_answers

  def find_account
    question_locale_group.find_account
  end

  def answers_count(filters: {})
    answer_scope = Answer.where(possible_answer_id: possible_answer_ids)

    Answer.answers_count(answer_scope, filters: filters)
  end

  def answer_rate(filters: {})
    percent_of(answers_count(filters: filters), question_locale_group.answers_count(filters: filters))
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
