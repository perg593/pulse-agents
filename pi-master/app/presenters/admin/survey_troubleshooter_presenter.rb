# frozen_string_literal: true

require_relative '../../../lib/custom_chrome_driver'

module Admin
  class SurveyTroubleshooterPresenter
    def initialize(survey, device_udid = nil, url = nil)
      @survey = survey
      @device_udid = device_udid
      @url = url
    end

    def props
      return {} if @survey.nil?

      {
        surveyId: @survey.id,
        surveyName: @survey.name,
        conditions: survey_rendering_conditions,
        deviceUdid: @device_udid,
        clientUrl: @url
      }
    end

    private

    def date_range_condition
      inside_date_range = if @survey.starts_at.nil? && @survey.ends_at.nil?
        nil
      else
        (@survey.starts_at.nil? || Time.current > @survey.starts_at) &&
          (@survey.ends_at.nil? || Time.current < @survey.ends_at)
      end

      return nil if inside_date_range.nil?

      return {
        satisfied: inside_date_range,
        message: "Inside target date range?"
      }
    end

    def frequency_cap_condition
      return nil unless @survey.frequency_cap_active?

      if device.nil?
        {
          satisfied: false,
          message: "PROVIDE DEVICE UDID TO CHECK -- Device below frequency cap?"
        }
      else
        {
          satisfied: !device.hit_frequency_cap_for_survey?(@survey),
          message: "Device below frequency cap?"
        }
      end
    end

    def refire_time_condition
      return nil unless @survey.refire_enabled

      if device.nil?
        {
          satisfied: false,
          message: "PROVIDE DEVICE UDID TO CHECK -- Device inside refire period?"
        }
      else
        {
          satisfied: device.eligible_for_refire_for_survey?(@survey),
          message: "Device eligible for refire?"
        }
      end
    end

    def survey_live_condition
      {
        satisfied: @survey.live?,
        message: "Is the survey live?"
      }
    end

    def survey_goal_condition
      {
        satisfied: !@survey.goal_reached?,
        message: "Has the survey's goal been reached?"
      }
    end

    def url_contains_condition
      url_triggers = UrlTrigger.where(survey_id: @survey.id)

      return nil unless url_triggers.present?

      unless @url.present?
        return [{
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- URL contains target?"
        }]
      end

      url_triggers.map do |url_trigger|
        passes = url_trigger.url_passes?(@url)
        target = url_trigger.url

        {
          satisfied: passes,
          message: "URL contains target (#{target})?"
        }
      end
    end

    def url_equals_condition
      url_matches_triggers = UrlMatchesTrigger.where(survey_id: @survey.id)

      return nil unless url_matches_triggers.present?

      unless @url.present?
        return [{
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- URL same as target?"
        }]
      end

      url_matches_triggers.map do |url_matches_trigger|
        passes = url_matches_trigger.url_passes?(@url)
        target = url_matches_trigger.url_matches

        {
          satisfied: passes,
          message: "URL same as target (#{target})?"
        }
      end
    end

    def url_regexp_matches_condition
      regexp_triggers = RegexpTrigger.where(survey_id: @survey.id).present?

      return nil unless regexp_triggers.present?

      unless @url.present?
        return [{
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- URL matches regular expression?"
        }]
      end

      regexp_triggers.map do |regexp_trigger|
        passes = regexp_trigger.url_passes?(@url)
        target = regexp_trigger.regexp

        {
          satisfied: passes,
          message: "URL matches regular expression? (#{target})?"
        }
      end
    end

    def inline_target_condition
      return nil unless @survey.inline_target_selector.present?

      if @url.blank?
        {
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- Is the inline target on the page?"
        }
      else
        {
          satisfied: client_page_body.css(@survey.inline_target_selector).present?,
          message: "Is the inline target on the page?"
        }
      end
    end

    def text_on_page_condition
      return nil unless @survey.text_on_page_trigger&.text_on_page_enabled

      unless @url.present?
        return {
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- Is the text on page trigger satisfied?"
        }
      end

      {
        satisfied: @survey.text_on_page_trigger.satisfied_with_page?(client_page_body),
        message: "Is the text on page trigger satisfied?"
      }
    end

    def visit_condition
      return nil unless @survey.visit_trigger

      {
        satisfied: false,
        message: "Visit trigger satisfied? #{@survey.visit_trigger.visitor_type} #{@survey.visit_trigger.visits_count}"
      }
    end

    def pageview_condition
      return nil unless @survey.pageview_trigger

      {
        satisfied: false,
        message: "Pageview trigger satisfied? #{@survey.pageview_trigger.pageviews_count}"
      }
    end

    def previous_answer_condition
      return nil unless @survey.answer_triggers.present?

      @survey.answer_triggers.map do |previous_answer_trigger|
        previous_survey = Survey.find(previous_answer_trigger.previous_answered_survey_id)
        previous_possible_answer = PossibleAnswer.find(previous_answer_trigger.previous_possible_answer_id)

        {
          satisfied: false,
          message: "Answer trigger satisfied? #{previous_possible_answer.content}\
          (#{previous_possible_answer.id}) for #{previous_survey.name} (#{previous_survey.id})"
        }
      end
    end

    def pseudo_event_condition
      return nil unless pseudo_event_trigger = PseudoEventTrigger.where(survey_id: @survey.id).first

      {
        satisfied: false,
        # rubocop:disable Layout/LineLength
        message: "Present alias (a.k.a. pseudo event trigger) satisfied? #{pseudo_event_trigger.excluded ? "suppress if" : "show if"} #{pseudo_event_trigger.pseudo_event}"
      }
    end

    def mobile_install_condition
      return nil unless @survey.mobile_install_trigger

      {
        satisfied: false,
        message: "Mobile install trigger satisfied? #{@survey.mobile_install_trigger.mobile_days_installed}"
      }
    end

    def mobile_launch_condition
      return nil unless @survey.mobile_launch_trigger

      {
        satisfied: false,
        message: "Mobile launch trigger satisfied? #{@survey.mobile_launch_trigger.mobile_days_installed}"
      }
    end

    def mobile_pageview_condition
      mobile_pageview_triggers = MobilePageviewTrigger.where(survey_id: @survey.id)

      return nil if mobile_pageview_triggers.empty?

      mobile_pageview_triggers.map do |mobile_pageview_trigger|
        {
          satisfied: false,
          message: "Mobile pageview trigger satisfied? #{mobile_pageview_trigger.excluded ? "suppress if" : "show if"} #{mobile_pageview_trigger.mobile_pageview}"
        }
      end
    end

    def mobile_regexp_condition
      mobile_regexp_triggers = MobileRegexpTrigger.where(survey_id: @survey.id)

      return nil if mobile_regexp_triggers.empty?

      mobile_regexp_triggers.map do |mobile_regexp_trigger|
        {
          satisfied: false,
          message: "Mobile regexp trigger satisfied? #{mobile_regexp_trigger.excluded ? "suppress if" : "show if"} #{mobile_regexp_trigger.mobile_regexp}"
        }
      end
    end

    def client_page_body
      @client_page_body ||= begin
        target_site_response = RestClient.get(@url)
        Nokogiri::HTML(target_site_response.body)
      end
    end

    def device
      @device ||= Device.find_by(udid: @device_udid)
    end

    def tag_present_on_page_condition
      unless @url.present?
        return {
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- Tag present on page?"
        }
      end

      satisfied = @webdriver.execute_script("return window['pi'] !== undefined")

      {
        satisfied: satisfied,
        message: "Is the tag on the page?"
      }
    end

    def page_element_visible_condition
      return nil unless @survey.page_element_visible_trigger&.render_after_element_visible_enabled

      unless @url.present?
        return {
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- Is the page element visible?"
        }
      end

      element_selector = @survey.page_element_visible_trigger.render_after_element_visible

      element_on_page = @webdriver.find_element({css: element_selector}).present?
      @webdriver.execute_script(<<~JS)
        window.foundIt = false;

        const observer = new IntersectionObserver((entries) => {
          if (entries[0].isIntersecting) {
            window.foundIt = true;
          }
        }, { threshold: 0 });

        const target = document.querySelector('#{element_selector}');
        observer.observe(target);
      JS

      # The IntersectionObserver works asynchronously. Give it time to run.
      element_in_viewport = Retryable.with_retry(max_retry_count: 3, interval: 1) do
        found_it = @webdriver.execute_script("return window.foundIt;")
        raise StandardError "IntersectionObserver did not find it" if found_it.nil?
      end

      satisfied = element_on_page && element_in_viewport

      {
        satisfied: satisfied,
        message: "Is the page element visible?"
      }
    end

    def page_element_clicked_condition
      return nil unless @survey.page_element_clicked_trigger&.render_after_element_clicked_enabled

      unless @url.present?
        return {
          satisfied: false,
          message: "PROVIDE URL TO CHECK -- Can the page element be clicked?"
        }
      end

      element_selector = @survey.page_element_clicked_trigger.render_after_element_clicked

      element = @webdriver.find_element({css: element_selector})

      satisfied = element.present?

      begin
        element&.click
      rescue Selenium::WebDriver::Error::ElementNotInteractableError => _e
        satisfied = false
      end

      {
        satisfied: satisfied,
        message: "Can the page element be clicked?"
      }
    end

    def page_scroll_trigger_condition
      return nil unless @survey.page_scroll_trigger&.render_after_x_percent_scroll_enabled

      scroll_amount = @survey.page_scroll_trigger.render_after_x_percent_scroll

      {
        satisfied: nil,
        message: "Does it show up after scrolling? #{scroll_amount}% of page"
      }
    end

    def exit_intent_condition
      return nil unless @survey.page_intent_exit_trigger&.render_after_intent_exit_enabled

      {
        satisfied: nil,
        message: "Does it show up on exit intent? (mouse near top of page)"
      }
    end

    def page_after_seconds_condition
      return nil unless @survey.page_after_seconds_trigger&.render_after_x_seconds_enabled

      seconds_to_wait = @survey.page_after_seconds_trigger.render_after_x_seconds

      {
        satisfied: nil,
        message: "Does it show up after waiting #{seconds_to_wait} seconds?"
      }
    end

    def geo_trigger_condition
      return nil unless @survey.geoip_triggers.present?

      triggers = @survey.geoip_triggers.map do |geoip_trigger|
        "#{geoip_trigger.geo_country} #{geoip_trigger.geo_state_or_dma}"
      end.join(", ")

      {
        satisfied: nil,
        message: "Geo triggers satisfied? #{triggers}"
      }
    end

    def device_data_condition
      return nil unless @survey.device_triggers

      {
        satisfied: nil,
        message: "Device data trigger satisfied?"
        # TODO
        # #{device_data_trigger.device_data_key} #{device_data_trigger.device_data_matcher} #{device_data_trigger.device_data_value}"
      }
    end

    def client_key_present_condition
      return nil unless @survey.client_key_trigger

      {
        satisfied: nil,
        message: "Client key trigger satisfied? Should be present? #{@survey.client_key_trigger.client_key_presence}"
      }
    end

    def targeting_overlap_condition
      {
        satisfied: nil,
        message: "Are there any other surveys on that page with overlapping triggers?"
      }
    end

    def mercury_in_retrograde_condition
      {
        satisfied: nil,
        message: "Is Mercury in retrograde? https://www.almanac.com/content/mercury-retrograde-dates"
      }
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def survey_rendering_conditions
      # TODO: Determine whether we successfully retrieved the page
      @webdriver = CustomChromeDriver.new
      @webdriver.get(@url) if @url.present?

      conditions = []
      conditions << survey_live_condition
      conditions << survey_goal_condition
      conditions << date_range_condition
      conditions << frequency_cap_condition
      conditions << refire_time_condition
      conditions += url_contains_condition if url_contains_condition
      conditions += url_equals_condition if url_equals_condition
      conditions += url_regexp_matches_condition if url_regexp_matches_condition
      conditions << inline_target_condition
      conditions << text_on_page_condition
      conditions << visit_condition
      conditions << pageview_condition
      conditions += previous_answer_condition if previous_answer_condition
      conditions << pseudo_event_condition
      conditions << mobile_install_condition
      conditions << mobile_launch_condition
      conditions += mobile_pageview_condition if mobile_pageview_condition
      conditions += mobile_regexp_condition if mobile_regexp_condition
      conditions << tag_present_on_page_condition
      conditions << page_element_visible_condition
      conditions << page_element_clicked_condition
      conditions << page_scroll_trigger_condition
      conditions << exit_intent_condition
      conditions << page_after_seconds_condition
      conditions << geo_trigger_condition
      conditions << device_data_condition
      conditions << client_key_present_condition
      conditions << targeting_overlap_condition
      conditions << mercury_in_retrograde_condition

      conditions.compact!
    ensure
      @webdriver&.clean_up
    end
  end
end
