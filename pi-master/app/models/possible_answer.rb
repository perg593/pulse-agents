# frozen_string_literal: true
class PossibleAnswer < ActiveRecord::Base
  include QrveySynchronization

  audited associated_with: :question

  default_scope { order(:created_at) }
  enum image_position_cd: { top: 0, bottom: 1, right: 2, left: 3 }
  belongs_to :question
  belongs_to :next_question, class_name: 'Question', optional: true
  belongs_to :answer_image, optional: true
  has_many   :answers, dependent: :nullify
  belongs_to :possible_answer_locale_group, optional: true
  has_many :locale_translation_caches, -> { where record_type: "PossibleAnswer" },
           class_name: "LocaleTranslationCache", foreign_key: :record_id, dependent: :destroy
  has_one :metadatum, class_name: "Metadata::PossibleAnswerMetadatum", foreign_key: :owner_record_id, inverse_of: :possible_answer, dependent: :destroy

  scope :sort_by_position, -> { reorder(:position) }

  validates :content, presence: true
  validates_format_of :image_height, :image_height_mobile, :image_height_tablet, :image_width, :image_width_mobile, :image_width_tablet,
                      with: /\A\d+(px|%)*\z/, allow_blank: true # Only accepts numbers with a unit("px" or "%") optionally attached to the end
  validates :report_color, rgb: true # RGB color format. Only allows values like #000 and #ffffff
  validate :no_circular_link
  validate { multi_choice_next_question_position if question.multiple_choices_question? }

  before_save :set_position
  after_save { update_translations if possible_answer_locale_group_id }

  def answers_count(filters: {})
    Answer.answers_count(answers, filters: filters)
  end

  def event_answer_count(event_name, filters: {})
    event_answers = answers.joins(:page_events).where(page_events: { name: event_name }).distinct
    Answer.answers_count(event_answers, filters: filters)
  end

  # Needed by Localization
  def expected_language_code
    question.survey.language_code
  end

  # Needed by Localization
  def self.translated_fields
    %i(
      content
    )
  end
  include Localization

  def base_possible_answer?
    self == possible_answer_locale_group&.base_possible_answer
  end

  def next_question_position
    Question.find_by(id: next_question_id)&.position
  end

  attr_accessor :ephemeral_next_question_id

  def direct_submission_link
    "//#{Rails.configuration.survey_host}/q/#{question_id}/a/#{id}?identifier=#{question.survey.account.identifier}"
  end

  def image_settings
    question.image_settings_before_type_cast
  end

  def apply_locale_group_routing
    if possible_answer_locale_group_id &&
       !next_question_id &&
       (base_possible_answer = possible_answer_locale_group.base_possible_answer) &&
       (group_position = base_possible_answer.next_question_position) &&
       (new_next_question_id = question.survey.questions.find_by(position: group_position)&.id)

      update(next_question_id: new_next_question_id)
    end
  end

  private

  def set_position
    self.position ||= question.possible_answers.count
  end

  def no_circular_link
    return if next_question_id.nil?

    errors.add(:next_question_id, "cannot link to its own question") if next_question_id == question_id
  end

  def multi_choice_next_question_position
    return if next_question_id.nil?

    last_position = question.possible_answers.reject(&:marked_for_destruction?).pluck(:position).max

    errors.add(:next_question_id, "only the last possible answer can have next question") if position < last_position
  end
end

# == Schema Information
#
# Table name: possible_answers
#
#  id                              :integer          not null, primary key
#  content                         :text
#  image_alt                       :string
#  image_height                    :string
#  image_height_mobile             :string
#  image_height_tablet             :string
#  image_position_cd               :integer
#  image_width                     :string
#  image_width_mobile              :string
#  image_width_tablet              :string
#  position                        :integer          not null
#  report_color                    :string
#  created_at                      :datetime
#  updated_at                      :datetime
#  answer_image_id                 :integer
#  next_question_id                :integer
#  possible_answer_locale_group_id :bigint
#  question_id                     :integer
#
# Indexes
#
#  index_possible_answers_on_content                          (content)
#  index_possible_answers_on_next_question_id                 (next_question_id)
#  index_possible_answers_on_possible_answer_locale_group_id  (possible_answer_locale_group_id)
#  index_possible_answers_on_question_id                      (question_id)
#
