# frozen_string_literal: true

class AppliedSurveyTag < ActiveRecord::Base
  audited associated_with: :survey

  belongs_to :survey_tag
  belongs_to :survey
end

# == Schema Information
#
# Table name: applied_survey_tags
#
#  id            :integer          not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  survey_id     :integer
#  survey_tag_id :integer
#
# Indexes
#
#  index_applied_survey_tags_on_survey_id      (survey_id)
#  index_applied_survey_tags_on_survey_tag_id  (survey_tag_id)
#
