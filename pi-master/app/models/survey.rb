# frozen_string_literal: true
class Survey < ActiveRecord::Base
  include SurveyPositionValueHander
  include SurveyExtraAttrs
  include SurveyExtraAttrs::Stats
  include QrveySynchronization

  audited associated_with: :account
  has_associated_audits

  mount_uploader :logo, LogoUploader
  mount_uploader :background, SurveyBackgroundUploader

  attr_accessor :create_default_associations

  enum status: { draft: 0, live: 1, paused: 2, complete: 3, archived: 4 }
  enum survey_type: { docked_widget: 0, inline: 1, top_bar: 2, bottom_bar: 3, fullscreen: 4 }
  enum inline_target_position: { below: 0, above: 1, before: 2, after: 3 }

  belongs_to :account
  belongs_to :theme, optional: true
  belongs_to :sdk_theme, optional: true, class_name: 'Theme'
  has_one :survey_stat, dependent: :destroy
  has_many :questions, -> { order(:position) }, dependent: :destroy
  has_many :form_questions, -> { order(:position) }, dependent: :nullify, class_name: 'Question'
  has_many :answers, through: :questions
  has_many :possible_answers, through: :questions
  has_one :first_question, lambda {
    where(question_type: Question.question_types[:single_choice_question]).
      where(position: 0)
  }, dependent: :nullify, class_name: 'Question'
  has_many :follow_up_questions, -> { where.not(position: 0).order(:position) }, dependent: :nullify, class_name: 'Question'
  has_many :free_text_questions, -> { where(question_type: 1) }, dependent: :nullify, class_name: 'Question'
  has_many :triggers, lambda {
    where(excluded: false).
      where('device_data_matcher IS NULL').
      where('type_cd IN (?)', %w(UrlTrigger RegexpTrigger MobilePageviewTrigger MobileRegexpTrigger UrlMatchesTrigger PseudoEventTrigger))
  }, dependent: :nullify, class_name: "Trigger"
  has_many :suppressers, lambda {
    where(excluded: true).
      where('type_cd IN (?)', %w(UrlTrigger RegexpTrigger MobilePageviewTrigger MobileRegexpTrigger UrlMatchesTrigger PseudoEventTrigger))
  }, dependent: :nullify, class_name: 'Trigger'
  has_one :pageview_trigger, dependent: :nullify
  has_one :visit_trigger, dependent: :nullify
  has_one :mobile_launch_trigger, dependent: :nullify
  has_one :mobile_install_trigger, dependent: :nullify
  has_one :page_after_seconds_trigger, dependent: :nullify
  has_one :page_scroll_trigger, dependent: :nullify
  has_one :page_intent_exit_trigger, dependent: :nullify
  has_one :page_element_clicked_trigger, dependent: :nullify
  has_one :page_element_visible_trigger, dependent: :nullify
  has_one :text_on_page_trigger, dependent: :nullify
  has_one :client_key_trigger, dependent: :nullify
  has_many :device_triggers, dependent: :nullify, class_name: "DeviceDataTrigger"
  has_many :answer_triggers, dependent: :nullify, class_name: "PreviousAnswerTrigger"
  has_many :geoip_triggers, dependent: :nullify, class_name: "GeoTrigger"
  has_many :submissions, -> { answered }, class_name: 'Submission', dependent: :nullify
  has_many :impressions, class_name: 'Submission', dependent: :nullify
  has_many :viewed_impressions, -> { viewed }, class_name: 'Submission', dependent: :nullify
  has_many :applied_survey_tags
  has_many :survey_tags, through: :applied_survey_tags
  has_one  :survey_stat, dependent: :destroy
  has_many :question_locale_groups, foreign_key: :owner_record_id, inverse_of: :survey
  belongs_to :survey_locale_group, optional: true
  has_many :submission_caches, class_name: "SurveySubmissionCache", dependent: :nullify # Destroy these asynchronously in #1109
  has_many :scheduled_report_surveys, dependent: :destroy
  has_many :recommendations, class_name: 'SurveyRecommendation', dependent: :destroy

  has_many :thank_you_diagram_properties, lambda {
    where node_type: 'ThankYou'
  }, class_name: "DiagramProperties", foreign_key: :node_record_id, dependent: :destroy

  has_many :invitation_diagram_properties, lambda {
    where node_type: 'Invitation'
  }, class_name: "DiagramProperties", foreign_key: :node_record_id, dependent: :destroy
  has_many :locale_translation_caches, -> { where record_type: "Survey" },
           class_name: "LocaleTranslationCache", foreign_key: :record_id, dependent: :destroy
  has_one :metadatum, class_name: "Metadata::SurveyMetadatum", foreign_key: :owner_record_id, inverse_of: :survey, dependent: :destroy
  has_one :last_survey_brief_job, -> { order(created_at: :desc) }, class_name: "SurveyBriefJob", foreign_key: :survey_id

  has_many :survey_overview_documents, dependent: :destroy
  has_many :ai_outline_jobs, dependent: :destroy
  has_many :survey_brief_jobs, dependent: :destroy
  has_many :survey_recommendations, dependent: :destroy

  scope :lives, lambda {
    where(status: Survey.statuses[:live]).
      where(%~("surveys"."starts_at" IS NULL OR
          (("surveys"."starts_at" AT TIME ZONE 'UTC') < (NOW() AT TIME ZONE 'UTC'))) AND
          ("surveys"."ends_at" IS NULL OR (("surveys"."ends_at" AT TIME ZONE 'UTC') > (NOW() AT TIME ZONE 'UTC')))~)
  }
  scope :lives_with_free_text_questions, -> { lives.joins(:questions).where(["questions.question_type = ?", 1]) }
  scope :not_archived, -> { where.not(status: :archived) }

  validates_numericality_of :width, only_integer: true, greater_than_or_equal_to: 0, allow_nil: true
  validates_format_of :top_position, :bottom_position, :right_position, :left_position, with: /\A\d+(px|%)\z/, allow_blank: true
  validates :answer_text_color, :background_color, :text_color, rgb: true # RGB color format. Only allows values like #000 and #ffffff
  validate            :goal_should_be_positive
  validate            :reject_non_native_theme
  validate            :validate_question_positions

  before_save :set_live_at, :set_right_position_and_width, :null_out_language_code
  after_save { update_translations if survey_locale_group_id }
  after_save { propagate_language_code if survey_locale_group_id }
  after_create :create_survey_stat
  after_create { set_default_url_trigger if create_default_associations }
  after_destroy :destroy_empty_survey_locale_group

  accepts_nested_attributes_for :questions, :form_questions, :first_question, :follow_up_questions, :triggers, :suppressers, :device_triggers,
                                :pageview_trigger, :visit_trigger, :answer_triggers, :mobile_launch_trigger, :mobile_install_trigger,
                                :page_after_seconds_trigger, :page_scroll_trigger, :page_intent_exit_trigger, :page_element_visible_trigger,
                                :page_element_clicked_trigger, :text_on_page_trigger, :geoip_triggers, :client_key_trigger,
                                :invitation_diagram_properties, :thank_you_diagram_properties, :applied_survey_tags, :last_survey_brief_job,
                                allow_destroy: true

  delegate :helpers, to: 'ActionController::Base'
  delegate :answers_count, to: :survey_stat, allow_nil: true

  REFIRE_TIME_PERIOD_OPTIONS = %w(minutes hours days).freeze

  # Needed by Localization
  def expected_language_code
    language_code
  end

  # Needed by Localization
  def self.translated_fields
    %i(
      all_at_once_submit_label
      all_at_once_error_text
      invitation
      invitation_button
      thank_you
    )
  end
  include Localization

  def updated_by_name
    possible_user_ids = audits.where.not(user_id: nil).descending.pluck(:user_id)

    possible_user_ids.each do |user_id|
      if user = User.find_by(id: user_id)
        return user.name
      end
    end

    return "unavailable"
  end

  def goal
    helpers.number_with_delimiter(self[:goal])
  end

  def goal=(value)
    self[:goal] = if value.is_a?(String)
      value.delete(',').to_i
    else
      value
    end
  end

  def expired?
    current_time = Time.now.utc
    (starts_at.present? && ends_at.blank? && current_time < starts_at) ||
      (ends_at.present? && starts_at.blank? && current_time > ends_at) ||
      (starts_at.present? && ends_at.present? && (starts_at > current_time || current_time > ends_at))
  end

  def localized?
    survey_locale_group_id.present?
  end

  # If you update this, please update the rack_app database.rb get_surveys method as well so that it's in SYNC
  # Please update get_survey... methods in files under rack/database as well if necessary
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength, Metrics/BlockLength
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def attributes_for_javascript
    columns = [:id, :name, :survey_type, :invitation, :top_position, :bottom_position, :left_position, :right_position, :width, :background_color, :text_color,
               :logo, :inline_target_selector, :custom_css, :theme_css, :thank_you, :pusher_enabled, :answer_text_color,
               :mobile_inline_target_selector, :sdk_inline_target_selector, :inline_target_position, :background, :fullscreen_margin,
               :display_all_questions, :invitation_button, :invitation_button_disabled, :single_page, :ignore_frequency_cap, :randomize_question_order,
               :all_at_once_empty_error_enabled, :all_at_once_submit_label, :all_at_once_error_text, :survey_locale_group_id]
    h = {}

    columns.each do |c|
      if [:id, :width].include?(c)
        h[c] = attributes[c.to_s].to_i
      elsif c == :survey_type
        h[c] = survey_type_before_type_cast
      elsif c == :inline_target_selector && survey_type == 'inline'
        h[:inline_target_selector] = '#inline_survey_target_area'
      elsif c == :theme_css
        h[c] = theme.try(:css)
      elsif c == :inline_target_position
        h[c] = read_attribute_before_type_cast(c).to_s
      elsif c == :background
        h[c] = background_url || remote_background
      elsif c == :display_all_questions
        h[c] = display_all_questions ? 't' : 'f'
      elsif c == :invitation_button_disabled
        h[c] = invitation_button_disabled ? 't' : 'f'
      elsif c == :randomize_question_order
        h[c] = randomize_question_order ? 't' : 'f'
      elsif c == :all_at_once_submit_label
        h[c] = all_at_once_submit_label.presence || 'Submit'
      elsif c == :all_at_once_error_text
        h[c] = all_at_once_error_text.presence || 'Please fill answers'
      elsif c == :all_at_once_empty_error_enabled
        h[c] = all_at_once_empty_error_enabled ? 't' : 'f'
      else
        h[c] = attributes[c.to_s].to_s
      end
    end

    h[:pulse_insights_branding] = account.try(:pulse_insights_branding)

    setting = account.personal_data_setting
    h[:personal_data_masking_enabled] = setting.masking_enabled
    h[:phone_number_masked]           = setting.phone_number_masked
    h[:email_masked]                  = setting.email_masked

    h
  end

  def free_text?
    free_text_questions.any?
  end

  def free_text_analyze_async!
    FreeTextAnalyzer.perform_async(id)
  end

  def free_text_analyze!
    free_text_questions.each(&:free_text_analyze!)
  end

  # NOTE: duplicated_survey.reattach_plumbing_lines(survey) must be called
  # afterwards to handle question-level routing.
  def duplicate
    copied_survey = deep_clone(
      include: [
        :triggers, :suppressers, :pageview_trigger, :visit_trigger, :device_triggers, :mobile_launch_trigger,
        :mobile_install_trigger, :page_after_seconds_trigger, :page_scroll_trigger, :page_intent_exit_trigger,
        :page_element_clicked_trigger, :page_element_visible_trigger, :device_triggers, :answer_triggers, :geoip_triggers,
        :text_on_page_trigger, { questions: [:possible_answers, :diagram_properties] }, :invitation_diagram_properties, :thank_you_diagram_properties
      ]
    )
    copied_survey.status = 'draft'
    copied_survey.name = "#{name} Copy"
    copied_survey.live_at = nil
    copied_survey.language_code = nil

    copied_survey
  end

  def localize!(group_name: nil)
    return unless survey_locale_group_id.nil?

    survey_locale_group = SurveyLocaleGroup.create(owner_record_id: account_id, name: group_name || name)
    update(survey_locale_group_id: survey_locale_group.id)
    update_translations(force: true)

    questions.each do |question|
      question_locale_group = QuestionLocaleGroup.create(name: question.content, owner_record_id: survey_locale_group.id)
      question.update(question_locale_group_id: question_locale_group.id)
      question.update_translations(force: true)

      question.possible_answers.order(:created_at).each do |possible_answer|
        possible_answer_locale_group = PossibleAnswerLocaleGroup.create(name: possible_answer.content, owner_record_id: question_locale_group.id)
        possible_answer.update(possible_answer_locale_group_id: possible_answer_locale_group.id)
        possible_answer.update_translations(force: true)
      end
    end
  rescue StandardError => e
    Rails.logger.info("Error Localizing #{e}")
    Rollbar.error(e, 'Error Localizing', survey_id: id, group_name: group_name)
  end

  def unlocalize!
    locale_translation_caches.destroy_all

    questions.includes(:locale_translation_caches).each do |question|
      question.locale_translation_caches.destroy_all
    end

    possible_answers.includes(:locale_translation_caches).each do |possible_answer|
      possible_answer.locale_translation_caches.destroy_all
    end

    update(survey_locale_group_id: nil)
    questions.update_all(question_locale_group_id: nil)
    possible_answers.update_all(possible_answer_locale_group_id: nil)
  end

  def add_to_localization_group(new_survey_locale_group_id, new_language_code)
    return false unless can_be_added_to_localization_group?(new_survey_locale_group_id)

    update(survey_locale_group_id: new_survey_locale_group_id, language_code: new_language_code)
    update_translations(force: true)

    base_survey = SurveyLocaleGroup.find_by(id: new_survey_locale_group_id).base_survey

    base_survey.questions.includes(:possible_answers).each_with_index do |base_question, question_index|
      question = questions[question_index]
      question.update(question_locale_group_id: base_question.question_locale_group_id)
      question.update_translations(force: true)

      base_question.possible_answers.each_with_index do |base_possible_answer, possible_answer_index|
        possible_answer = question.possible_answers[possible_answer_index]
        possible_answer.update(possible_answer_locale_group_id: base_possible_answer.possible_answer_locale_group_id)
        possible_answer.update_translations(force: true)
      end
    end

    true
  end

  def base_survey?
    self == survey_locale_group&.base_survey
  end

  def reattach_plumbing_lines(original_survey)
    original_survey.questions.each do |original_question|
      original_next_question_position = original_question.next_question_position
      duplicated_question = questions.find_by(position: original_question.position)

      original_question.possible_answers.sort_by_position.each do |original_possible_answer|
        next unless original_possible_answer.next_question_id

        # Selecting the same possible_answer from duplicated survey
        possible_answer = duplicated_question.possible_answers.find_by(position: original_possible_answer.position)

        # Select the same next question from duplicated survey
        next_question = questions.find_by(position: original_possible_answer.next_question_position)

        possible_answer.update(next_question_id: next_question.id)
      end

      next unless original_question.next_question_id.present? || original_question.free_text_next_question_id.present?

      duplicated_next_question = questions.find_by(position: original_next_question_position)

      if original_question.next_question_id.present?
        duplicated_question.update(next_question_id: duplicated_next_question.id)
      elsif original_question.free_text_next_question_id.present?
        duplicated_question.update(free_text_next_question_id: duplicated_next_question.id)
      end
    end
  end

  def applied_survey_tag_names
    survey_tags.pluck(:name).join(",")
  end

  def first_ever_launch_date
    live_at = audits.creates.pick(:audited_changes)&.dig('live_at')
    live_at ||= audits.updates.where("audited_changes::jsonb ? 'live_at'").order(:created_at).pick(:audited_changes)&.dig('live_at')&.last
    live_at
  end

  # This is where we save routing that went to questions that
  # did not exist in the db at the time of submission
  def reconcile_routing
    questions.each do |question|
      question.possible_answers.each do |possible_answer|
        ephemeral_next_question_id = possible_answer.ephemeral_next_question_id

        next_question = questions.detect { |q| q.ephemeral_id == ephemeral_next_question_id } if ephemeral_next_question_id
        possible_answer.update(next_question_id: next_question.id) if next_question
      end

      if question.ephemeral_next_question_id
        next_question = questions.detect { |q| q.ephemeral_id == question.ephemeral_next_question_id }
        question.update(next_question_id: next_question.id) if next_question
      elsif question.ephemeral_free_text_next_question_id
        next_question = questions.detect { |q| q.ephemeral_id == question.ephemeral_free_text_next_question_id }
        question.update(free_text_next_question_id: next_question.id) if next_question
      end
    end
  end

  def goal_reached?
    survey_stat.answers_count >= self[:goal]
  end

  def frequency_cap_active?
    return false if ignore_frequency_cap?
    return false unless account.frequency_cap_enabled?

    true
  end

  def summarize
    summary = ""

    summary += "When the device is an Android. " if android_enabled
    summary += "When the device is a desktop. " if desktop_enabled
    summary += "When the device is an iPhone. " if ios_enabled
    summary += "When the device is an e-mail client. " if email_enabled
    summary += "When the device is a tablet. " if tablet_enabled
    summary += "With a sample rate of #{sample_rate}%. " if sample_rate

    summary += "With a refire time of #{refire_time} #{refire_time_period}. " if refire_enabled
    summary += "With a start date of #{starts_at.strftime("%m/%d/%Y")}. " if starts_at
    summary += "With an end date of #{ends_at.strftime("%m/%d/%Y")}. " if ends_at
    summary += "Will stop showing if the user has closed the survey without answering it." if stop_showing_without_answer
    summary += "Will ignore frequency limits, showing the survey every time. " if ignore_frequency_cap

    summary
  end

  private

  # unique, no gaps, 0-based
  def validate_question_positions
    return if questions.empty?

    questions_to_save = questions.reject(&:marked_for_destruction?)

    return if (0..questions_to_save.size - 1).to_a == questions_to_save.sort_by(&:position).map(&:position)

    errors.add :questions, "question order is bad: #{questions_to_save.map(&:position)}"
  end

  def propagate_language_code
    return unless locale_translation_caches.first && locale_translation_caches.first.expected_language_code != language_code

    locale_translation_caches.update_all(expected_language_code: language_code)

    questions.each do |question|
      question.locale_translation_caches.update_all(expected_language_code: language_code)

      question.possible_answers.each do |possible_answer|
        possible_answer.locale_translation_caches.update_all(expected_language_code: language_code)
      end
    end
  end

  def can_be_added_to_localization_group?(new_survey_locale_group_id)
    return false if survey_locale_group_id.present?

    new_survey_locale_group = SurveyLocaleGroup.find_by(id: new_survey_locale_group_id)
    return false unless new_survey_locale_group

    base_survey = new_survey_locale_group.base_survey
    return false unless base_survey
    return false if base_survey.account != account
    return false if base_survey.questions.count != questions.count

    base_survey.questions.includes(:possible_answers).each_with_index do |base_question, question_index|
      return false unless base_question.possible_answers.count == questions[question_index].possible_answers.count

      base_next_question = Question.find_by(id: base_question.next_question_id)
      next_question = Question.find_by(id: questions[question_index].next_question_id)

      return false unless base_next_question&.position == next_question&.position
    end

    true
  end

  def goal_should_be_positive
    self[:goal].is_a?(String) && self[:goal].positive?
  end

  def set_live_at
    if status_changed?
      self[:live_at] = (Time.now.utc if status == 'live' && status_was != 'live')
    end
    true
  end

  def set_right_position_and_width
    if docked_widget?
      left_position.blank? && self[:right_position] ||= '10%'
      !width_changed? && self[:width] ||= 300
    end
    true
  end

  def set_default_url_trigger
    trigger = UrlTrigger.new(survey: self)
    trigger.save!
  end

  def reject_non_native_theme
    return if sdk_theme.nil?

    errors.add :sdk_theme, "sdk_theme has to be 'native' type" unless sdk_theme.native?
  end

  def null_out_language_code
    self.language_code = nil if language_code.blank?
  end

  # used in SurveyExtraAttrs::Stats for duck typing
  def survey_ids_for_stats
    [id]
  end

  def destroy_empty_survey_locale_group
    return if survey_locale_group.nil? || survey_locale_group.surveys.present?

    survey_locale_group.destroy
  end
end

# == Schema Information
#
# Table name: surveys
#
#  id                              :integer          not null, primary key
#  all_at_once_empty_error_enabled :boolean          default(FALSE)
#  all_at_once_error_text          :string
#  all_at_once_submit_label        :string
#  android_enabled                 :boolean          default(FALSE)
#  answer_text_color               :string(255)
#  background                      :string
#  background_color                :string(255)
#  bottom_position                 :string(255)
#  custom_css                      :text
#  desktop_enabled                 :boolean          default(TRUE)
#  display_all_questions           :boolean          default(FALSE)
#  email_enabled                   :boolean          default(FALSE), not null
#  ends_at                         :datetime
#  first_call_at                   :datetime
#  fullscreen_margin               :integer
#  goal                            :integer          default(5000)
#  ignore_frequency_cap            :boolean          default(FALSE)
#  inline_target_position          :integer          default("below")
#  inline_target_selector          :text
#  invitation                      :string(255)
#  invitation_button               :string
#  invitation_button_disabled      :boolean          default(FALSE)
#  ios_enabled                     :boolean          default(FALSE)
#  language_code                   :string
#  left_position                   :string(255)
#  live_at                         :datetime
#  locale_code                     :string
#  logo                            :string(255)
#  mobile_enabled                  :boolean          default(TRUE)
#  mobile_inline_target_selector   :text
#  name                            :string(255)
#  poll_enabled                    :boolean
#  pusher_enabled                  :boolean          default(FALSE)
#  randomize_question_order        :boolean          default(FALSE)
#  refire_enabled                  :boolean          default(FALSE)
#  refire_time                     :integer
#  refire_time_period              :string
#  remote_background               :string
#  right_position                  :string(255)
#  sample_rate                     :integer          default(100)
#  sdk_inline_target_selector      :text
#  sdk_widget_height               :integer          default(0)
#  single_page                     :boolean          default(FALSE)
#  starts_at                       :datetime
#  status                          :integer          default("draft")
#  stop_showing_without_answer     :boolean          default(FALSE)
#  survey_type                     :integer          default("docked_widget")
#  tablet_enabled                  :boolean          default(TRUE)
#  text_color                      :string(255)
#  thank_you                       :string(255)
#  top_position                    :string(255)
#  width                           :integer
#  created_at                      :datetime
#  updated_at                      :datetime
#  account_id                      :integer
#  sdk_theme_id                    :integer
#  survey_locale_group_id          :bigint
#  theme_id                        :integer
#
# Indexes
#
#  index_surveys_on_account_id              (account_id)
#  index_surveys_on_ends_at                 (ends_at)
#  index_surveys_on_first_call_at           (first_call_at)
#  index_surveys_on_goal                    (goal)
#  index_surveys_on_name                    (name)
#  index_surveys_on_sample_rate             (sample_rate)
#  index_surveys_on_sdk_theme_id            (sdk_theme_id)
#  index_surveys_on_starts_at               (starts_at)
#  index_surveys_on_status                  (status)
#  index_surveys_on_survey_locale_group_id  (survey_locale_group_id)
#  index_surveys_on_survey_type             (survey_type)
#  index_surveys_on_theme_id                (theme_id)
#
