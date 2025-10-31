# frozen_string_literal: true

class Automation < ActiveRecord::Base
  audited except: [:last_triggered_at, :times_triggered], associated_with: :account
  has_associated_audits

  belongs_to :account
  has_many :conditions, class_name: 'AutomationCondition', dependent: :destroy
  has_many :actions, class_name: 'AutomationAction', dependent: :destroy

  validates :conditions, length: { minimum: 1 }
  validates :conditions, length: { maximum: 1 }, if: :url?
  validates :actions, length: { minimum: 1 }
  validates :actions, length: { maximum: 1 }, if: :create_event?
  validates :name, presence: true
  validates :condition_type, presence: true
  validates :action_type, presence: true

  validate :check_condition_action_combination

  enum condition_type: { answer_text: 0, url: 1 }
  enum action_type: { send_email: 0, create_event: 1 }
  enum trigger_type: { any_condition: 0, all_conditions: 1 }

  attr_accessor :surveys

  accepts_nested_attributes_for :conditions, :actions

  scope :enabled, -> { where(enabled: true) }

  def url_condition
    conditions.where.not(url_matcher: nil).first
  end

  def emails
    actions.pluck(:email).compact
  end

  def match?(answer_text, question_id)
    matching_conditions = conditions.
                          where("automation_conditions.question_id IS NULL OR automation_conditions.question_id = :question_id",
                                question_id: question_id).
                          map { |condition| answer_text.downcase.include?(condition.condition.downcase) }

    return false if matching_conditions.empty?

    case trigger_type
    when 'all_conditions'
      matching_conditions.exclude?(false)
    when 'any_condition'
      matching_conditions.include?(true)
    else
      false
    end
  end

  def update_trigger_stats
    update(times_triggered: (times_triggered || 0) + 1, last_triggered_at: Time.current)
  end

  def check_condition_action_combination
    return if condition_type.blank? || action_type.blank?
    return if condition_type == 'answer_text' && action_type == 'send_email'
    return if condition_type == 'url' && action_type == 'create_event'
    errors.add :base, 'condition_type and action_type not matching'
  end
end

# == Schema Information
#
# Table name: automations
#
#  id                :integer          not null, primary key
#  action_type       :integer          default("send_email"), not null
#  condition_type    :integer          default("answer_text"), not null
#  enabled           :boolean          default(FALSE)
#  last_triggered_at :datetime
#  name              :string
#  times_triggered   :integer
#  trigger_type      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer
#
# Indexes
#
#  index_automations_on_account_id  (account_id)
#
