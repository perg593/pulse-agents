# frozen_string_literal: true

class Trigger < ActiveRecord::Base
  default_scope { order(:id) }

  self.inheritance_column = :type_cd

  TYPES = { 'URL Contains' => 'UrlTrigger',
            'Regex Matches' => 'RegexpTrigger',
            'URL Is' => 'UrlMatchesTrigger',
            'View Name Contains' => 'MobilePageviewTrigger',
            'Regex View Name Matches' => 'MobileRegexpTrigger',
            'Present Alias Contains' => 'PseudoEventTrigger' }.freeze

  audited associated_with: :survey

  belongs_to :survey

  VALID_TYPE_CDS = %w(
    RegexpTrigger UrlTrigger PageviewTrigger VisitTrigger PreviousAnswerTrigger
    MobilePageviewTrigger MobileRegexpTrigger MobileLaunchTrigger MobileInstallTrigger
    PageAfterSecondsTrigger PageScrollTrigger PageElementVisibleTrigger PageElementClickedTrigger
    PageIntentExitTrigger TextOnPageTrigger GeoTrigger ClientKeyTrigger UrlMatchesTrigger
    PseudoEventTrigger DeviceDataTrigger
  ).freeze
  validates :type_cd, inclusion: { in: VALID_TYPE_CDS, message: "type_cd must be one of #{VALID_TYPE_CDS}" }

  before_validation :set_url_and_regexp

  def trigger_content
    "placeholder"
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def trigger_content=(value)
    url_will_change! if type_cd == "UrlTrigger" && url != value
    regexp_will_change! if type_cd == "RegexpTrigger" && regexp != value
    mobile_pageview_will_change! if type_cd == "MobilePageviewTrigger" && mobile_pageview != value
    mobile_regexp_will_change! if type_cd == "MobileRegexpTrigger" && mobile_regexp != value
    url_matches_will_change! if type_cd == "UrlMatchesTrigger" && url_matches != value
    pseudo_event_will_change! if type_cd == "PseudoEventTrigger" && pseudo_event != value

    @trigger_content = value
  end

  private

  # We allow the frontend to send "trigger_content", which we interpret here
  def set_url_and_regexp
    return unless @trigger_content

    case type_cd
    when "UrlTrigger"
      self.url = @trigger_content
    when "RegexpTrigger"
      self.regexp = @trigger_content
    when "MobilePageviewTrigger"
      self.mobile_pageview = @trigger_content
    when "UrlMatchesTrigger"
      self.url_matches = @trigger_content
    when "PseudoEventTrigger"
      self.pseudo_event = @trigger_content
    when "MobileRegexpTrigger"
      self.mobile_regexp = @trigger_content
    end
  end
end

# == Schema Information
#
# Table name: triggers
#
#  id                                    :integer          not null, primary key
#  client_key_presence                   :boolean          default(FALSE)
#  device_data_key                       :string
#  device_data_mandatory                 :boolean          default(TRUE), not null
#  device_data_matcher                   :string
#  device_data_value                     :string
#  excluded                              :boolean          default(FALSE)
#  geo_country                           :string
#  geo_state_or_dma                      :string
#  mobile_days_installed                 :integer          default(0)
#  mobile_launch_times                   :integer          default(0)
#  mobile_pageview                       :string
#  mobile_regexp                         :string
#  pageviews_count                       :integer          default(0)
#  pseudo_event                          :string
#  regexp                                :string(255)
#  render_after_element_clicked          :string
#  render_after_element_clicked_enabled  :boolean
#  render_after_element_visible          :string
#  render_after_element_visible_enabled  :boolean
#  render_after_intent_exit_enabled      :boolean
#  render_after_x_percent_scroll         :integer
#  render_after_x_percent_scroll_enabled :boolean
#  render_after_x_seconds                :integer
#  render_after_x_seconds_enabled        :boolean
#  text_on_page_enabled                  :boolean
#  text_on_page_presence                 :boolean
#  text_on_page_selector                 :string
#  text_on_page_value                    :string
#  type_cd                               :string
#  url                                   :string(255)
#  url_matches                           :string
#  visitor_type                          :integer          default(0)
#  visits_count                          :integer          default(0)
#  created_at                            :datetime
#  updated_at                            :datetime
#  previous_answered_survey_id           :integer
#  previous_possible_answer_id           :integer
#  survey_id                             :integer
#
# Indexes
#
#  index_triggers_on_excluded   (excluded)
#  index_triggers_on_survey_id  (survey_id)
#
