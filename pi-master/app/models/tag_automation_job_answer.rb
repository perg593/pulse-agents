# frozen_string_literal: true

class TagAutomationJobAnswer < ActiveRecord::Base
  belongs_to :tag_automation_job
  belongs_to :answer
end

# == Schema Information
#
# Table name: tag_automation_job_answers
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  answer_id             :bigint           not null
#  tag_automation_job_id :bigint           not null
#
# Indexes
#
#  index_tag_automation_job_answers_on_answer_id              (answer_id)
#  index_tag_automation_job_answers_on_tag_automation_job_id  (tag_automation_job_id)
#
