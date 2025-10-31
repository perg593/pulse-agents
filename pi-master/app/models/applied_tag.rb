# frozen_string_literal: true

class AppliedTag < ActiveRecord::Base
  audited associated_with: :answer

  belongs_to :tag
  belongs_to :answer
  belongs_to :tag_automation_job, optional: true

  validates :answer_id, uniqueness: { scope: :tag_id }

  scope :automated, -> { where.not(tag_automation_job_id: nil) }

  def approved?
    !automated? || is_good_automation?
  end

  def automated?
    tag_automation_job.present?
  end
end

# == Schema Information
#
# Table name: applied_tags
#
#  id                    :integer          not null, primary key
#  is_good_automation    :boolean
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  answer_id             :integer
#  tag_automation_job_id :integer
#  tag_id                :integer
#
# Indexes
#
#  index_applied_tags_on_answer_id_with_tag_id  (answer_id,tag_id)
#
