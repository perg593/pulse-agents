# frozen_string_literal: true

require_relative '../services/google'

class SurveyOverviewDocument < ApplicationRecord
  audited

  enum status: [:pending, :capturing_remote_screenshots,
                :generating_slides, :completed, :failed]

  belongs_to :survey

  mount_uploader :survey_editor_screenshot, SurveyOverviewScreenshotUploader
  mount_uploaders :client_page_screenshots_desktop, SurveyOverviewScreenshotUploader
  mount_uploaders :client_page_screenshots_mobile, SurveyOverviewScreenshotUploader

  scope :unfinished, -> { where.not(status: [:completed, :failed]) }

  VALID_CLIENT_SITE_CONFIG_KEYS = %w(target_url cookie_selectors viewport_config authentication_config).freeze
  TEMPLATE_PRESENTATION_ID = "1WfIoxk2qQi41VR9xG79g-StM5CVi69kgsAGqjAJ0AIc"

  validates :survey, presence: true
  validate :validate_client_site_configuration_format
  validate :no_unfinished_jobs, unless: ->(doc) { doc.completed? || doc.failed? }

  before_save :set_status
  before_save :normalize_viewport_config

  store_accessor :client_site_configuration, :target_url, :cookie_selectors, :viewport_config, :authentication_config

  def google_presentation_url
    return unless google_presentation_id.present?

    "https://docs.google.com/presentation/d/#{google_presentation_id}/edit"
  end

  def fail!(reason)
    update!(
      status: :failed,
      failure_reason: reason
    )
  end

  def text_replacement_data
    {
      'survey_name' => survey.name,
      'account_name' => survey.account.name,
      'date' => Date.today.strftime('%B %Y'),
      'client_homepage' => target_url, # TODO: Clarify this with PI
      'brief' => survey.last_survey_brief_job&.brief,
      'frequency' => "#{survey.sample_rate}%",
      'targeted_urls' => survey.triggers.map(&:summarize).join("\n"),
      'suppressed_urls' => survey.suppressers.map(&:summarize).join("\n"),
      'widget_location' => survey.survey_type.titleize,
      'frequency_cap' => survey.ignore_frequency_cap? ? "No limit" : survey.account.frequency_cap_in_words
    }
  end

  # Generate a Google Slides presentation from the survey overview document
  # @return [String] The ID of the generated presentation
  def generate_presentation
    return unless screenshots_present?

    @drive_service = Google::SurveyOverviewPresentationService.new
    self.google_presentation_id = copy_and_share_presentation

    update_presentation_content

    update!(google_presentation_id: google_presentation_id)
    google_presentation_id
  end

  def take_screenshots_of_client_page
    # wipe existing screenshots
    self.client_page_screenshots_desktop = []
    self.client_page_screenshots_mobile = []

    screenshot_taker = SurveyWidgetScreenshotTaker.new(survey, target_url, cookie_selectors, viewport_config, authentication_config)

    self.client_page_screenshots_desktop = screenshot_taker.take_desktop_screenshots
    self.client_page_screenshots_mobile = screenshot_taker.take_mobile_screenshots

    save
  end

  def custom_content_data
    # Get all custom content questions from the survey
    custom_content_questions = survey.questions.custom_content_question

    # Create a hash mapping each card name to its links
    custom_content_questions.each_with_object({}) do |question, result|
      card_name = question.content
      links = question.custom_content_links
      result[card_name] = links.map do |link|
        {
          text: link.link_text,
          url: link.link_url
        }
      end
    end
  end

  private

  def trigger_rules
    targeting_rules(trigger: true)
  end

  def suppression_rules
    targeting_rules(trigger: false)
  end

  def targeting_rules(trigger: false)
    targeting = trigger ? survey.triggers : survey.suppressers

    targeting.where(type_cd: %w(UrlTrigger UrlMatchesTrigger)).map do |target|
      ["#{Trigger::TYPES.invert[target.type_cd]}: ", target.trigger_content]
    end
  end

  def screenshots_present?
    survey_editor_screenshot.present? &&
      client_page_screenshots_desktop.present? &&
      client_page_screenshots_mobile.present?
  end

  def copy_and_share_presentation
    new_presentation_name = "Survey Overview Document - #{survey.name} - #{Date.today.strftime('%Y-%m-%d')}"
    copied_file = @drive_service.copy_file(TEMPLATE_PRESENTATION_ID, new_presentation_name)
    @drive_service.share_file_with_organization(copied_file.id)
    copied_file.id
  end

  def update_presentation_content
    replace_text_and_content
    replace_screenshots
    replace_rules
  end

  def replace_text_and_content
    @drive_service.replace_text_placeholders(google_presentation_id, text_replacement_data)

    if survey.last_survey_brief_job&.done?
      @drive_service.remove_survey_brief_slide_identifier(google_presentation_id)
    else
      @drive_service.remove_survey_brief_slide(google_presentation_id)
    end

    @drive_service.replace_custom_content_link_box_content(google_presentation_id, custom_content_data)
  end

  def replace_screenshots
    @drive_service.replace_canvas_slide_image(google_presentation_id, survey_editor_screenshot)
    @drive_service.replace_client_page_screenshots(
      google_presentation_id,
      client_page_screenshots_desktop,
      client_page_screenshots_mobile
    )
  end

  def replace_rules
    @drive_service.replace_trigger_urls_content(google_presentation_id, trigger_rules)
    @drive_service.replace_suppressed_urls_content(google_presentation_id, suppression_rules)
  end

  def set_status
    return if status_changed?

    self.status = if survey_editor_screenshot.present?
      if client_page_screenshots_desktop.present? && client_page_screenshots_mobile.present?
        if google_presentation_id.present?
          :completed
        else
          :generating_slides
        end
      else
        :capturing_remote_screenshots
      end
    else
      :pending
    end
  end

  def validate_client_site_configuration_format
    return if client_site_configuration.blank?

    # Check for invalid keys
    invalid_keys = client_site_configuration.keys - VALID_CLIENT_SITE_CONFIG_KEYS
    if invalid_keys.any?
      errors.add(:client_site_configuration, "contains invalid keys: #{invalid_keys.join(', ')}")
    end

    # Validate target_url is present and is a valid URL
    if target_url.blank?
      errors.add(:client_site_configuration, "must include a target_url")
    elsif !target_url.is_a?(String) || !target_url.match?(/\A#{URI::DEFAULT_PARSER.make_regexp(%w(http https))}\z/)
      errors.add(:client_site_configuration, "target_url must be a valid URL")
    end

    # Validate cookie_selectors is an array if present
    if client_site_configuration.key?('cookie_selectors') && !cookie_selectors.is_a?(Array)
      errors.add(:client_site_configuration, "cookie_selectors must be an array")
    end

    # Validate viewport_config if present
    validate_viewport_configuration if client_site_configuration.key?('viewport_config')
  end

  def no_unfinished_jobs
    return unless self.class.unfinished.where(survey_id: survey_id).where.not(id: id).exists?

    errors.add(:status, "A survey overview document is already being generated. Please wait for it to complete.")
  end

  def normalize_viewport_config
    return unless client_site_configuration&.dig('viewport_config').present?

    viewport_config = client_site_configuration['viewport_config']
    normalized_config = {}

    viewport_config.each do |key, value|
      # Convert string values to integers if they're numeric strings
      normalized_config[key] = if value.is_a?(String) && value.match?(/\A\d+\z/)
        value.to_i
      else
        value
      end
    end

    client_site_configuration['viewport_config'] = normalized_config
  end

  def validate_viewport_configuration
    config = viewport_config
    return unless config.present?

    validate_viewport_config_hash(config)
    validate_viewport_config_keys(config)
    validate_viewport_config_values(config)
  end

  def validate_viewport_config_hash(config)
    return if config.is_a?(Hash)

    errors.add(:client_site_configuration, "viewport_config must be a hash")
  end

  def validate_viewport_config_keys(config)
    valid_viewport_keys = %w(width height desktop_width desktop_height mobile_width mobile_height)
    invalid_keys = config.keys - valid_viewport_keys
    return if invalid_keys.empty?

    errors.add(:client_site_configuration, "viewport_config contains invalid keys: #{invalid_keys.join(', ')}")
  end

  def validate_viewport_config_values(config)
    config.each do |key, value|
      numeric_value = convert_to_numeric(value)
      validate_numeric_value(key, numeric_value)
      validate_dimension_ranges(key, numeric_value)
    end
  end

  def convert_to_numeric(value)
    value.is_a?(String) ? value.to_i : value
  end

  def validate_numeric_value(key, numeric_value)
    return if numeric_value.is_a?(Integer) && numeric_value.positive?

    errors.add(:client_site_configuration, "viewport_config.#{key} must be a positive integer")
  end

  def validate_dimension_ranges(key, numeric_value)
    if key.include?('width') && (numeric_value < 320 || numeric_value > 3840)
      errors.add(:client_site_configuration, "viewport_config.#{key} must be between 320 and 3840 pixels")
    elsif key.include?('height') && (numeric_value < 240 || numeric_value > 2160)
      errors.add(:client_site_configuration, "viewport_config.#{key} must be between 240 and 2160 pixels")
    end
  end
end

# == Schema Information
#
# Table name: survey_overview_documents
#
#  id                              :bigint           not null, primary key
#  client_page_screenshots_desktop :json
#  client_page_screenshots_mobile  :json
#  client_site_configuration       :jsonb            not null
#  failure_reason                  :text
#  status                          :integer          default("pending")
#  survey_editor_screenshot        :string
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  google_presentation_id          :string
#  survey_id                       :bigint           not null
#
# Indexes
#
#  index_survey_overview_documents_on_client_site_configuration  (client_site_configuration)
#  index_survey_overview_documents_on_status                     (status)
#  index_survey_overview_documents_on_survey_id                  (survey_id)
#
# Foreign Keys
#
#  fk_rails_...  (survey_id => surveys.id)
#
