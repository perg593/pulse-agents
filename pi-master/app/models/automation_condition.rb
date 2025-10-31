# frozen_string_literal: true

class AutomationCondition < ActiveRecord::Base
  audited associated_with: :automation

  belongs_to :automation
  belongs_to :question, optional: true

  validate :check_question_belongs_to_account

  enum url_matcher: { url_is: 0, url_contains: 1, url_matches: 2 }

  def url_meets_condition?(url)
    case url_matcher
    when 'url_is'
      url == condition
    when 'url_contains'
      url.include? condition
    when 'url_matches'
      url.match? condition
    end
  end

  def check_question_belongs_to_account
    return if question.nil?
    errors.add(:question_id, "Question doesn't belong to Account") unless Question.find_by(survey: automation.account.surveys)
  end
end

# == Schema Information
#
# Table name: automation_conditions
#
#  id            :integer          not null, primary key
#  condition     :string
#  url_matcher   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  automation_id :integer
#  question_id   :integer
#
# Indexes
#
#  index_automation_conditions_on_automation_id  (automation_id)
#  index_automation_conditions_on_question_id    (question_id)
#
