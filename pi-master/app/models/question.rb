# frozen_string_literal: true
class Question < ActiveRecord::Base
  include QrveySynchronization

  audited except: :keyword_extraction, associated_with: :survey
  has_associated_audits

  # Update Rack::DatabaseWorker#load_survey_questions_and_possible_answers if add a new question_type
  enum question_type: { single_choice_question: 0, free_text_question: 1, custom_content_question: 2, multiple_choices_question: 3, slider_question: 4 }
  enum answers_alignment_desktop: { left: 0, center: 1, right: 2, space_between: 3, space_around: 4, space_evenly: 5 }, _prefix: true
  enum answers_alignment_mobile: { left: 0, center: 1, right: 2, space_between: 3, space_around: 4, space_evenly: 5 }, _prefix: true
  enum button_type: { radio: 0, standard: 1, menu: 2 }
  enum desktop_width_type: { fixed: 0, variable: 1 }, _prefix: true
  enum mobile_width_type: { fixed: 0, variable: 1 }, _prefix: true
  enum image_settings: { image_only: 0, text_and_image: 1 }
  enum additional_content_position: { between: 0, footer: 1, header: 2 }

  belongs_to :survey
  has_many :ai_summarization_jobs, dependent: :nullify
  has_many :possible_answers, dependent: :nullify
  has_many :answers, dependent: :nullify
  has_many :tags, -> { where.not(name: Tag::AUTOMATION_PLACEHOLDER_NAME) }
  has_many :applied_tags, through: :tags
  has_many :answer_images, as: :imageable
  belongs_to :question_locale_group, optional: true
  has_many :diagram_properties, -> { where node_type: 'Question' }, class_name: "DiagramProperties", foreign_key: :node_record_id, dependent: :destroy
  has_many :locale_translation_caches, -> { where record_type: "Question" },
           class_name: "LocaleTranslationCache", foreign_key: :record_id, dependent: :destroy
  has_many :custom_content_links, -> { active }
  has_many :custom_content_link_clicks, through: :custom_content_links, source: :clicks
  has_many :tag_automation_jobs, dependent: :destroy
  has_one :metadatum, class_name: "Metadata::QuestionMetadatum", foreign_key: :owner_record_id, inverse_of: :question, dependent: :destroy

  scope :sort_by_position, -> { order(:position) }

  validates :survey, :question_type, presence: true
  validates_presence_of :content, unless: :custom_content_question?
  validates :slider_start_position, numericality: { only_integer: true }, if: :slider_question?
  validates :slider_submit_button_enabled, inclusion: { in: [true, false] }, if: :slider_question?
  validates :background_color, rgb: true # RGB color format. Only allows values like #000 and #ffffff
  validate :no_circular_link

  accepts_nested_attributes_for :possible_answers, allow_destroy: true
  accepts_nested_attributes_for :diagram_properties

  before_validation :set_answers_per_row
  before_validation :set_position
  before_validation :set_slider_start_position, if: :slider_question?
  before_validation :set_slider_submit_button_enabled, if: :slider_question?
  after_save { update_translations if question_locale_group_id }
  after_save :situate_custom_content_links

  attr_accessor :randomize_checkbox, :ephemeral_id, :ephemeral_next_question_id, :ephemeral_free_text_next_question_id

  store_accessor :additional_text, :before_question_text, :after_question_text, :before_answers_count, :after_answers_count, :before_answers_items,
                 :after_answers_items

  RANDOMIZE_ALL = 0
  RANDOMIZE_ALL_EXCEPT_LAST = 1

  RANDOMIZE_OPTIONS = [['all responses', RANDOMIZE_ALL], ['all responses, except the last', RANDOMIZE_ALL_EXCEPT_LAST]].freeze
  WIDTH_TYPE_OPTIONS = [['Fixed Width', 'fixed'], ['Variable Width', 'variable']].freeze

  NUM_NPS_POSSIBLE_ANSWERS = 11

  # Needed by Localization
  def expected_language_code
    survey.language_code
  end

  # Needed by Localization
  def self.translated_fields
    %i(
      content
      hint_text
      submit_label
      error_text
      empty_error_text
      maximum_selections_exceeded_error_text
    )
  end
  include Localization

  def base_question?
    self == question_locale_group&.base_question
  end

  def next_question
    Question.find_by(id: next_question_id || free_text_next_question_id)
  end

  def next_question_position
    next_question&.position
  end

  def answer_rates(filters: {})
    total = answers_count(true, filters: filters)

    possible_answers.sort_by_position.map do |possible_answer|
      count = possible_answer.answers_count(filters: filters)
      rate = total.zero? ? 0 : count.to_f / total

      { possible_answer: possible_answer, answers_count: count, answer_rate: rate }
    end
  end

  def answers_count(group_udid = nil, filters: {})
    Answer.answers_count(answers, ignore_multiple_type_dup: multiple_choices_question? && group_udid, filters: filters)
  end

  def custom_content_link_click_count(filters: {})
    CustomContentLinkClick.filtered_clicks(custom_content_link_clicks, filters: filters).count
  end

  # submission_ids is empty when a bar is unselected
  def filtered_answers_count(submission_ids, filters: {})
    filtered_answers = answers
    filtered_answers = filtered_answers.where(submission_id: submission_ids) if submission_ids.present?

    filtered_answers = Answer.filtered_answers(filtered_answers, filters: filters)

    answers_per_possible_answer = filtered_answers.group('possible_answer_id').count

    response_counts = multiple_choices_question? ? filtered_answers.count('distinct(submission_id)') : filtered_answers.count
    ungrouped_response_counts = filtered_answers.count

    { responses: response_counts, answers: answers_per_possible_answer, ungrouped_responses: ungrouped_response_counts }
  end

  def free_text_analyze!
    # Don't do anything if it's not a free text question
    return if question_type != "free_text_question"

    # Don't do anything if there's not any non-analyzed question
    return if answers.where(analyzed: false).count.zero?

    # Analyze all the questions that haven't been analyzed
    answers.where(analyzed: false).each(&:free_text_analyze!)

    # Heavy part - gathering all the keywords
    # Getting an array of json objects
    keywords = answers.map(&:extracted_keywords)
    aggregated_keywords = free_text_aggregated_keywords(keywords)

    # Averaging the keywords scores by dividing by the number of answers in total
    answers_count = answers.count
    return if answers_count.zero?

    averaged_keywords = {}
    aggregated_keywords.each_pair { |keyword, score| averaged_keywords[keyword] = score / answers_count.to_f }

    # Save results
    update(keyword_extraction: averaged_keywords,
           positive_sentiment: 0,
           negative_sentiment: 0)
  end

  # Aggregating the keywords (summing)
  def free_text_aggregated_keywords(keywords)
    keywords.each_with_object({}) do |k, h|
      k.each_pair { |keyword, score| h[keyword] = h[keyword].nil? ? score : h[keyword] + score }
      h
    end
  end

  def free_text_direct_submission_link
    "//#{Rails.configuration.survey_host}/q/#{id}?identifier=#{survey.account.identifier}&text="
  end

  def next_question_allowed?
    %w(free_text_question custom_content_question multiple_choices_question).include? question_type
  end

  def due_for_tag_automation?
    tag_automation_worker_enabled && free_text_question? && tags.exists?
  end

  def self.image_settings_for_select
    image_settings.map do |setting, val|
      [setting.humanize, val]
    end
  end

  def self.answers_alignment_for_select
    answers_alignment_desktops.keys.map do |alignment|
      [alignment.humanize, alignment]
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def apply_locale_group_routing
    if question_locale_group_id &&
       ((free_text_question? && !free_text_next_question_id) ||
       (question_type == "multiple_choices_question" && !next_question_id)) &&
       (base_question = question_locale_group.base_question) &&
       (next_position = base_question.next_question_position) &&
       (new_next_question_id = survey.questions.find_by(position: next_position)&.id)

      if free_text_question?
        update(free_text_next_question_id: new_next_question_id)
      else
        update(next_question_id: new_next_question_id)
      end
    end
  end

  private

  def set_answers_per_row
    if nps?
      self.answers_per_row_desktop ||= 11
      self.answers_per_row_mobile ||= 6
    elsif single_choice_question? || multiple_choices_question?
      self.answers_per_row_desktop ||= 3
      self.answers_per_row_mobile ||= 3
    end
  end

  def set_position
    return true if position.present?
    self.position = survey.questions.size
  end

  def set_slider_start_position
    self.slider_start_position ||= possible_answers.size / 2
  end

  def set_slider_submit_button_enabled
    self.slider_submit_button_enabled = true if slider_submit_button_enabled.nil?
  end

  def no_circular_link
    errors.add(:next_question_id, "cannot link to itself") if next_question_id && next_question_id == id
    errors.add(:free_text_next_question_id, "cannot link to itself") if free_text_next_question_id && free_text_next_question_id == id
  end

  def situate_custom_content_links
    return unless previous_changes.keys.include? 'custom_content'
    SituateCustomContentLinksWorker.new.perform(id)
  end
end

# == Schema Information
#
# Table name: questions
#
#  id                                     :integer          not null, primary key
#  additional_content                     :text
#  additional_content_position            :integer          default("between")
#  additional_text                        :jsonb
#  answers_alignment_desktop              :integer
#  answers_alignment_mobile               :integer
#  answers_per_row_desktop                :integer
#  answers_per_row_mobile                 :integer
#  autoclose_delay                        :integer
#  autoclose_enabled                      :boolean
#  autoredirect_delay                     :integer
#  autoredirect_enabled                   :boolean
#  autoredirect_url                       :string
#  background_color                       :string
#  button_type                            :integer          default("standard")
#  content                                :text
#  custom_content                         :text
#  desktop_width_type                     :integer          default("fixed")
#  empty_error_text                       :string(255)
#  enable_maximum_selection               :boolean
#  error_text                             :string(255)
#  fullscreen                             :boolean          default(FALSE)
#  height                                 :integer          default(1)
#  hint_text                              :string(255)
#  image_settings                         :integer
#  keyword_extraction                     :json
#  max_length                             :integer          default(141)
#  maximum_selection                      :integer
#  maximum_selections_exceeded_error_text :string
#  mobile_width_type                      :integer          default("fixed")
#  negative_sentiment                     :float
#  nps                                    :boolean          default(FALSE)
#  opacity                                :integer
#  optional                               :boolean          default(FALSE)
#  position                               :integer          not null
#  positive_sentiment                     :float
#  question_type                          :integer          default("single_choice_question")
#  randomize                              :integer
#  show_additional_content                :boolean          default(FALSE)
#  show_after_aao                         :boolean          default(FALSE)
#  single_choice_default_label            :string
#  slider_start_position                  :integer
#  slider_submit_button_enabled           :boolean
#  submit_label                           :string(255)      default("Submit")
#  tag_automation_worker_enabled          :boolean          default(FALSE), not null
#  created_at                             :datetime
#  updated_at                             :datetime
#  free_text_next_question_id             :integer
#  next_question_id                       :integer
#  question_locale_group_id               :bigint
#  survey_id                              :integer
#
# Indexes
#
#  index_questions_on_content                   (content)
#  index_questions_on_question_locale_group_id  (question_locale_group_id)
#  index_questions_on_question_type             (question_type)
#  index_questions_on_survey_id                 (survey_id)
#
