# frozen_string_literal: true
class ClientKeyTrigger < Trigger
  validates :client_key_presence, exclusion: [nil]

  def summarize
    return unless client_key_presence

    "Client key must be present"
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
