# frozen_string_literal: true
module SurveyPositionValueHander
  extend ActiveSupport::Concern

  POSITION_TYPES = {
    top_position: 'Top Browser Edge',
    bottom_position: 'Bottom Browser Edge',
    right_position: 'Right Browser Edge',
    left_position: 'Left Browser Edge'
  }.freeze

  included do
    before_validation :set_position
  end

  def position_type
    if self[:left_position].present?
      'left_position'
    elsif self[:right_position].present?
      'right_position'
    end
  end

  def position_content
    self[:left_position].presence || self[:right_position].presence
  end

  def position_type=(value)
    if position_content != value
      left_position_will_change!
      right_position_will_change!
    end
    @position_type = value
  end

  def position_content=(value)
    left_position_will_change! if self[:left_position].present? && self[:left_position] != value
    right_position_will_change! if self[:right_position].present? && self[:right_position] != value
    @position_content = value
  end

  private
  def set_position
    if @position_type.present? && @position_content.blank?
      errors.add(:position_content, 'must be present')
      return false
    end

    return true if @position_type.blank? || @position_content.blank?

    self.left_position = nil
    self.right_position = nil
    self.top_position = nil
    self.bottom_position = nil
    send("#{@position_type}=", @position_content)
  end
end
