# frozen_string_literal: true

class DeviceDataTrigger < Trigger
  # NOTE: The rack app relies on these exact values for filtering
  # TODO: Convert these to an enum
  DEVICE_DATA_MATCHER_IS = "is"
  DEVICE_DATA_MATCHER_IS_NOT = "is_not"
  DEVICE_DATA_MATCHER_CONTAINS = "contains"
  DEVICE_DATA_MATCHER_DOES_NOT_CONTAIN = "does_not_contain"
  DEVICE_DATA_MATCHER_IS_TRUE = "is_true"
  DEVICE_DATA_MATCHER_IS_NOT_TRUE = "is_not_true"
  DEVICE_DATA_MATCHER_IS_MORE_THAN = "is_more_than"
  DEVICE_DATA_MATCHER_IS_EQUAL_OR_MORE_THAN = "is_equal_or_more_than"
  DEVICE_DATA_MATCHER_IS_EQUAL_OR_LESS_THAN = "is_equal_or_less_than"
  DEVICE_DATA_MATCHER_IS_LESS_THAN = "is_less_than"

  DEVICE_DATA_MATCHERS = [
    DEVICE_DATA_MATCHER_IS,
    DEVICE_DATA_MATCHER_IS_NOT,
    DEVICE_DATA_MATCHER_CONTAINS,
    DEVICE_DATA_MATCHER_DOES_NOT_CONTAIN,
    DEVICE_DATA_MATCHER_IS_TRUE,
    DEVICE_DATA_MATCHER_IS_NOT_TRUE,
    DEVICE_DATA_MATCHER_IS_MORE_THAN,
    DEVICE_DATA_MATCHER_IS_EQUAL_OR_MORE_THAN,
    DEVICE_DATA_MATCHER_IS_EQUAL_OR_LESS_THAN,
    DEVICE_DATA_MATCHER_IS_LESS_THAN
  ].freeze

  validates_presence_of :device_data_key, :device_data_matcher
  validates :device_data_value, presence: true, if: -> { ![DEVICE_DATA_MATCHER_IS_TRUE, DEVICE_DATA_MATCHER_IS_NOT_TRUE].include?(device_data_matcher) }
  validates :device_data_value, absence: true, if: -> { [DEVICE_DATA_MATCHER_IS_TRUE, DEVICE_DATA_MATCHER_IS_NOT_TRUE].include?(device_data_matcher) }
  validates :device_data_mandatory, exclusion: [nil]

  validates :device_data_matcher, inclusion: { in: DEVICE_DATA_MATCHERS }

  def summarize
    "Device data key '#{device_data_key}' #{device_data_matcher} '#{device_data_value}'"
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
