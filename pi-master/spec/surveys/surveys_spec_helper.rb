# frozen_string_literal: true
#
# rubocop:disable Metrics/ModuleLength -- We need a lot of help
module SurveysSpecHelper
  RAILS_APP_PORT = 8888

  @server_process = nil

  # Execute a given Javascript code in a given HTML with Chrome, e.g.
  #
  #    run_in_browser("return 1+1", "<html></html>", helper_options: { network_log: true }, selenium_options: { user_agent: 'Google' })
  #
  # helpers_options:
  #   (WIP) network_log ... returns network log
  # selenium_options:
  #   user_agent ... sets user agent
  def run_in_browser(js, html, helper_options: {}, selenium_options: {})
    file = html_test_file(html)
    driver   = setup_driver(file, selenium_options)

    result = if helper_options[:network_log]
      { result: driver.execute_script(js), network_log: driver.logs.get('browser').map(&:message) }
    else
      driver.execute_script(js)
    end

    driver.close

    result
  end

  def setup_driver(html_file, options = {})
    options = setup_options(options)
    driver = Selenium::WebDriver.for :chrome, options: options
    driver.get("file://#{html_file.path}")

    wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
    wait.until { driver.execute_script("return typeof PulseInsightsObject == 'object' && typeof pi == 'function'") }

    driver.manage.window.resize_to(800, 800)

    driver
  end

  def setup_options(user_options = {})
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('no-sandbox')              # for CI
    options.add_argument('--headless')              # for CI
    options.add_argument('--disable-dev-shm-usage') # for CI
    options.add_argument("--user-agent=#{user_options[:user_agent]}") if user_options[:user_agent]
    options
  end

  def html_test_file(html)
    htmlfile = Tempfile.new(['test', '.html'])
    htmlfile.write(html)
    htmlfile.close
    htmlfile
  end

  def html_test_page(account)
    <<-html

    <html>
      <head>
        <title>Survey test page</title>
        #{account.tag_code}
      </head>
      <body>
        <div id='inline_survey_target_area'></div>
      </body>
    </html>

    html
  end

  def start_rails_server
    environment = 'test'
    server      = 'thin'
    port        = RAILS_APP_PORT.to_s

    ENV['SIDEKIQ_INLINE'] = 'true'

    process = ChildProcess.build(*['rackup', '-E', environment, '-p', port, '-s', server].compact)
    process.start

    # Make sure the socket responds
    Timeout.timeout(30) do
      loop do
        begin
          ::TCPSocket.new('127.0.0.1', port).close
          break
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
          # Ignore, server still not available
          next
        end
        sleep 0.1
      end
    end

    # Do a first request
    Net::HTTP.start('127.0.0.1', port) do |http|
      request = Net::HTTP::Get.new '/heartbeat', {}
      http.request(request)
    end

    process
  end

  def stop_rails_server(server)
    server.stop

    Timeout.timeout(5) do
      loop do
        break if server.exited?
      end
    end
  end

  def setup_driver_via_http
    options = setup_options
    driver = Selenium::WebDriver.for :chrome, options: options

    # https://developer.mozilla.org/en-US/docs/Web/WebDriver/Errors/InvalidCookieDomain
    # page needs to be fetched via HTTP as cookies/storage operation is disabled in "data:" protocol, which seems to be the default for headless mode.
    #
    # https://www.selenium.dev/documentation/en/support_packages/working_with_cookies/
    # recommended to use a page with small load like '404' when presetting Cookies/Local Storage
    driver.navigate.to("http://localhost:#{RAILS_APP_PORT}/404")

    # operations that need to be executed before tag load
    yield driver if block_given?

    # load tag js
    tag_js = account.tag_code.remove(/<(\/)?script>/).remove(/\n/)
    driver.execute_script(<<~JS)
      var script = document.createElement('script');
      script.innerText = "#{tag_js}";
      document.body.appendChild(script);
    JS

    wait = Selenium::WebDriver::Wait.new(timeout: 30) # seconds
    wait.until { driver.execute_script("return typeof(window.PulseInsightsObject) == 'object';") }

    driver
  end

  def find_element(selector, timeout: 5)
    find_all_elements(selector, timeout: timeout)&.first
  end

  def find_all_elements(selector, timeout: 5)
    driver.current_url # Waking up the lazy-loaded driver

    wait = Selenium::WebDriver::Wait.new(timeout: timeout)
    wait.until { driver.find_elements(selector).presence }
  rescue Selenium::WebDriver::Error::TimeoutError => e
    nil
  end

  def it_renders_the_question(question)
    question_element = find_element({id: "_pi_question_#{question.id}"})

    expect(question_element).not_to be_nil
  end

  def survey_widget_type(survey)
    "#{survey.survey_type.classify.downcase}survey"
  end

  def survey_widget
    find_element({id: "_pi_surveyWidget"})
  end
end
