# frozen_string_literal: true
class SurveyStat < ActiveRecord::Base
  belongs_to :survey
end

# == Schema Information
#
# Table name: survey_stats
#
#  id            :integer          not null, primary key
#  answers_count :integer          default(0)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  survey_id     :integer
#
# Indexes
#
#  index_survey_stats_on_survey_id  (survey_id)
#
