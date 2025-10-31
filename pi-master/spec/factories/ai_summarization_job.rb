# frozen_string_literal: true
FactoryBot.define do
  factory :ai_summarization_job do
    status { :pending }
  end
end

# == Schema Information
#
# Table name: ai_summarization_jobs
#
#  id          :bigint           not null, primary key
#  status      :integer          default("pending")
#  summary     :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  question_id :bigint
#
# Indexes
#
#  index_ai_summarization_jobs_on_question_id  (question_id)
#
