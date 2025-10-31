# frozen_string_literal: true

# snapshot_id
# account_identifier
# client_url
module LiveSurveySpecHelper
  def visit_client_site
    uri = URI(client_url)
    uri.query = "#{uri.query}&disable_widget=t" if use_staging_widget

    driver.get(uri)

    return unless use_staging_widget

    # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2724
    sleep 5.1 # waiting on survey

    driver.execute_script(staging_tag_code)
  end

  def take_screenshot(description)
    sleep 1.0

    @snapshot_counter += 1

    name = "#{snapshot_id} -- #{@snapshot_counter} -- #{description}"

    Percy.snapshot(driver, name, snapshot_options)
  end

  private

  def snapshot_options
    { scope: "._pi_surveyWidgetContainer"}
  end

  def staging_tag_code
    @survey_js_host = "//js-staging.pulseinsights.com"
    @survey_host = "staging-survey.pulseinsights.com"
    @present_results = false
    @identifier = account_identifier

    tag_js = TagJsFileHelpers.tag_js(tag_js_version)

    ERB.new(tag_js).result(binding) # See this file to see all the bindings
  end

  def use_staging_widget
    ENV["USE_STAGING_WIDGET"]
  end
end
