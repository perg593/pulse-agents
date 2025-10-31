# frozen_string_literal: true

class SurveyRecommendation < ApplicationRecord
  belongs_to :survey

  validates :survey_id, presence: true

  scope :recent, -> { order(created_at: :desc).limit(10) }
end

# == Schema Information
#
# Table name: survey_recommendations
#
#  id         :bigint           not null, primary key
#  content    :jsonb
#  filters    :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  survey_id  :bigint           not null
#
# Indexes
#
#  index_survey_recommendations_on_survey_id_and_created_at  (survey_id,created_at)
#
