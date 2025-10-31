# frozen_string_literal: true

require_relative '../../lib/custom_chrome_driver'

class SurveyWidgetScreenshotTaker
  def initialize(survey, target_url, cookie_selectors = [], viewport_config = {}, authentication_config = {})
    @survey = survey
    @target_url = target_url
    @cookie_selectors = cookie_selectors
    @viewport_config = viewport_config
    @authentication_config = authentication_config
    @screenshots = []

    FileUtils.mkdir_p screenshot_root
  end

  def take_desktop_screenshots
    take_screenshots(device_type: :desktop)
  end

  def take_mobile_screenshots
    take_screenshots(device_type: :mobile)
  end

  private

  def take_screenshots(device_type:)
    @screenshots = []
    @device = device_type

    # Determine viewport configuration for the current device type
    viewport = device_type == :mobile ? mobile_viewport : desktop_viewport
    @webdriver = CustomChromeDriver.new(mobile: device_type == :mobile, viewport: viewport)

    visit_page_and_take_screenshots

    @screenshots
  ensure
    @webdriver&.clean_up
  end

  def device_suffix
    @device == :mobile ? "mobile" : "desktop"
  end

  def visit_client_page
    Rails.logger.info("Visiting client page: #{@target_url}")

    if @authentication_config['type'] == 'basic'
      handle_basic_authentication
    else
      @webdriver.get(@target_url)
    end
  end

  def accept_cookies
    Rails.logger.info("Accepting cookies: #{@cookie_selectors}")

    @cookie_selectors.each do |cookie_selector|
      body = @webdriver.find_element({css: "body"})
      body&.click

      cookie_accept_button = @webdriver.find_element({css: cookie_selector})

      Rails.logger.info("Found cookie accept button: #{cookie_accept_button}")

      cookie_accept_button&.click
    end
  rescue Selenium::WebDriver::Error::ElementNotInteractableError => _e
    # TODO: Handle the error
  end

  def handle_basic_authentication
    Rails.logger.info("Handling HTTP Basic Authentication")

    username = @authentication_config['username']
    password = @authentication_config['password']

    if username.blank? || password.blank?
      Rails.logger.error("Basic authentication credentials are missing")
      raise "Basic authentication requires both username and password"
    end

    # Create URL with basic auth credentials
    uri = URI.parse(@target_url)
    uri.user = username
    uri.password = password

    @webdriver.get(uri.to_s)
  end

  def handle_form_authentication
    Rails.logger.info("Handling HTML form authentication")

    username = @authentication_config['username']
    password = @authentication_config['password']
    form_selectors = @authentication_config['form_selectors'] || {}

    if username.blank? || password.blank?
      Rails.logger.error("Form authentication credentials are missing")
      raise "Form authentication requires both username and password"
    end

    # Fill username field
    fill_form_field(form_selectors['username_selector'], username, 'username field')

    # Fill password field
    fill_form_field(form_selectors['password_selector'], password, 'password field')

    # Find and click submit button
    submit_selector = form_selectors['submit_selector']
    submit_button = find_element_with_fallbacks(submit_selector, default_submit_selectors, 'submit button')
    submit_button.click
    Rails.logger.info("Clicked submit button")

    # Wait for authentication to complete (redirect or page change)
    sleep(2)
  end

  def fill_form_field(selector, value, field_name)
    field = find_element_with_fallbacks(selector, default_selectors_for_field(field_name), field_name)
    field.clear
    field.send_keys(value)
    Rails.logger.info("Filled #{field_name} with selector: #{field}")
  end

  def find_element_with_fallbacks(user_selector, default_selectors, element_name)
    selectors_to_try = []
    selectors_to_try << user_selector if user_selector.present?
    selectors_to_try += default_selectors

    selectors_to_try.each do |current_selector|
      next unless element = @webdriver.find_element({css: current_selector})
      Rails.logger.info("Found #{element_name} with selector: #{current_selector}")
      return element
    end

    Rails.logger.error("Could not find #{element_name} with any selector: #{selectors_to_try.join(', ')}")
    raise "#{element_name.capitalize} not found with any selector: #{selectors_to_try.join(', ')}"
  end

  def default_selectors_for_field(field_name)
    case field_name
    when 'username field'
      [
        'input[name="username"]',
        'input[name="user"]',
        'input[name="email"]',
        'input[name="login"]',
        'input[type="email"]',
        'input[type="text"]',
        '#username',
        '#user',
        '#email',
        '#login',
        '.username',
        '.user',
        '.email'
      ]
    when 'password field'
      [
        'input[name="password"]',
        'input[name="pass"]',
        'input[type="password"]',
        '#password',
        '#pass',
        '.password',
        '.pass'
      ]
    else
      []
    end
  end

  def default_submit_selectors
    [
      'button[type="submit"]',
      'input[type="submit"]',
      'button.submit',
      'button.login',
      'button.signin',
      'button.sign-in',
      '.submit',
      '.login',
      '.signin',
      '.sign-in',
      '#submit',
      '#login',
      '#signin',
      '#sign-in'
    ]
  end

  def accept_invitation
    @webdriver.execute_script("window.PulseInsightsObject.survey.startButtonClicked();")
  end

  def present_survey
    Rails.logger.info("presenting survey")

    @webdriver.execute_script(<<~JS)
      window.pi('preview',true);
      window.pi('present', #{@survey.id});
    JS
  end

  def present_question(question, question_index)
    if question.custom_content_question?
      @webdriver.execute_script(<<~JS)
        window.PulseInsightsObject.survey.questions[#{question_index}].autoclose_enabled = 'f';
      JS
    end

    @webdriver.execute_script(<<~JS)
      window.PulseInsightsObject.survey.question = window.PulseInsightsObject.survey.questions[#{question_index}];
      window.PulseInsightsObject.survey.renderCurrentQuestion();
    JS
  end

  def take_screenshots_of_questions
    if @survey.display_all_questions
      take_screenshot_of_aao_survey
    else
      @survey.questions.each_with_index do |question, i|
        take_screenshot_of_question(question, i)
      end
    end
  end

  def take_screenshot_of_question(question, question_index)
    present_question(question, question_index)
    screenshot_path = "#{screenshot_root}/question_#{question_index}_#{device_suffix}.png"

    take_screenshot(screenshot_path)
  end

  def take_screenshot_of_invitation
    screenshot_path = "#{screenshot_root}/client_page_#{device_suffix}.png"

    take_screenshot(screenshot_path)
  end

  def take_screenshot_of_aao_survey
    screenshot_path = "#{screenshot_root}/aao_survey_#{device_suffix}.png"

    take_screenshot(screenshot_path)
  end

  def take_screenshot_of_thank_you
    @webdriver.execute_script('window.PulseInsightsObject.survey.renderThankYou();')
    screenshot_path = "#{screenshot_root}/thank_you_#{device_suffix}.png"

    take_screenshot(screenshot_path)
  end

  def visit_page_and_take_screenshots
    # Visit the client's site
    visit_client_page

    # Handle form authentication if needed
    if @authentication_config['type'] == 'form'
      handle_form_authentication
    end

    # Deal with any cookie banners
    accept_cookies

    wait = Selenium::WebDriver::Wait.new(timeout: 5)
    wait.until { @webdriver.execute_script("return typeof window.PulseInsightsObject === 'object';") }
    wait.until { @webdriver.execute_script("return window.pi !== undefined;") }

    # Present the survey
    present_survey

    wait.until { @webdriver.execute_script("return window.PulseInsightsObject.survey !== undefined;") }

    if @survey.invitation.present?
      # Take screenshot of survey's invitation if it has one
      take_screenshot_of_invitation

      # Accept invitation
      accept_invitation
    end

    # Wait until questions have been downloaded
    wait.until { @webdriver.execute_script("return window.PulseInsightsObject.survey.questions !== undefined;") }

    # Take screenshots of each of the survey's questions
    take_screenshots_of_questions

    # Take screenshot of survey's "than you"
    take_screenshot_of_thank_you
  end

  def take_screenshot(screenshot_path)
    scroll_survey_into_view if @survey.inline?
    @webdriver.save_screenshot(screenshot_path)
    @screenshots << File.open(screenshot_path)
  end

  def scroll_survey_into_view
    wait = Selenium::WebDriver::Wait.new(timeout: 5)
    wait.until { @webdriver.execute_script("return document.getElementById('_pi_surveyWidgetContainer') !== null;") }

    @webdriver.execute_script("document.getElementById('_pi_surveyWidgetContainer').scrollIntoView({block:'center'});")
  end

  def screenshot_root
    "#{Rails.root}/tmp/widget_screenshots/#{@survey.id}/"
  end

  def desktop_viewport
    {
      width: @viewport_config['desktop_width'] || @viewport_config['width'],
      height: @viewport_config['desktop_height'] || @viewport_config['height']
    }.compact
  end

  def mobile_viewport
    {
      width: @viewport_config['mobile_width'] || @viewport_config['width'],
      height: @viewport_config['mobile_height'] || @viewport_config['height']
    }.compact
  end
end
