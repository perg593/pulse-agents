# frozen_string_literal: true

class Tag < ActiveRecord::Base
  AUTOMATION_PLACEHOLDER_NAME = 'Unable to AutoTag'
  MANUALLY_TAGGED_ANSWER_SAMPLE_SIZE = 5 # Some examples seem sufficient for GPT to grasp the existing tagging patterns

  audited associated_with: :question

  belongs_to :question
  has_many :applied_tags, dependent: :destroy
  has_many :manually_applied_tags, -> { where.not(<<-SQL) }, class_name: 'AppliedTag', dependent: :destroy
    EXISTS(SELECT 1 FROM tag_automation_jobs WHERE tag_automation_jobs.id = applied_tags.tag_automation_job_id)
  SQL
  has_many :manually_tagged_answers, through: :manually_applied_tags, source: :answer, dependent: :nullify

  validates_presence_of :question_id, :name, :color
  validates_uniqueness_of :name, scope: :question_id, case_sensitive: false

  # TODO: After upgrading to Rails 7, use "normalizes"
  # https://github.com/rails/rails/pull/43945
  before_validation :strip_whitespace

  # Used in TagAutomationWorker when GPT-3 has failed to tag an answer
  def self.placeholder(question)
    create_with(color: 'black').find_or_create_by(question: question, name: Tag::AUTOMATION_PLACEHOLDER_NAME)
  end

  def sample_manually_tagged_answer_texts
    manually_tagged_answers.order('RANDOM()').limit(MANUALLY_TAGGED_ANSWER_SAMPLE_SIZE).pluck(:text_answer)
  end

  private

  def strip_whitespace
    name&.strip!
  end
end

# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  color       :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  question_id :integer
#
# Indexes
#
#  index_tags_on_question_id                            (question_id)
#  index_tags_on_question_id_and_name_case_insensitive  (question_id, lower((name)::text)) UNIQUE
#
