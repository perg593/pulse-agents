# frozen_string_literal: true

class CustomChromeDriver < Selenium::WebDriver::Chrome::Driver
  def initialize(args: [], mobile: false, viewport: {})
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--user-data-dir=#{user_data_directory}") unless Rails.env.development?
    options.add_argument("--enable-logging")
    options.add_argument("--v=1")

    if mobile
      # Samsung Galaxy S22
      user_agent = <<~STR.squish
        Mozilla/5.0 (Linux; Android 12; SM-S906B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.5112.69 Crosswalk/104.0.5112.69 Mobile Safari/537.36
      STR

      # Use custom viewport dimensions if provided, otherwise use defaults
      width = viewport[:width] || 400
      height = viewport[:height] || 800

      options.add_emulation(
        user_agent: user_agent,
        device_metrics: {width: width, height: height, pixelRatio: 1, touch: true}
      )
    elsif viewport[:width] && viewport[:height]
      # Set desktop viewport dimensions if provided
      options.add_argument("--window-size=#{viewport[:width]},#{viewport[:height]}")
    end

    args.each { |arg| options.add_argument(arg) }

    super(options: options)
  end

  # Find a single element on the page
  # @param selector [Hash] The selector to use (e.g., {css: "#my-id"})
  # @param timeout [Integer] Maximum time to wait for the element
  # @return [Selenium::WebDriver::Element, nil] The found element or nil
  def find_element(selector, timeout: 5)
    wait = Selenium::WebDriver::Wait.new(timeout: timeout)

    wait.until do
      if selector[:css]&.include?("::shadow")
        find_in_shadows(selector[:css])
      else
        super(selector)
      end
    end
  rescue Selenium::WebDriver::Error::TimeoutError => _e
    nil
  end

  # Clean up the user data directory
  def clean_up
    quit
    clean_up_user_data_directory unless Rails.env.development?
  end

  private

  # Find an element, piercing successive shadow DOMs as necessary
  # @param selector [String] The selector to use (e.g., "#my-id")
  # @return [Selenium::WebDriver::Element, nil] The found element or nil
  def find_in_shadows(selector)
    execute_script(<<~JS)
      let target_element = null;
      const selectors = '#{selector}'.split('::shadow');
      let currentParent = document;

      for (let i = 0; i < selectors.length; i++) {
        const currentSelector = selectors[i];
        const element = currentParent.querySelector(currentSelector)

        if (element == null) {
          break;
        }

        if (i == selectors.length - 1) {
          target_element = element;
        } else {
          currentParent = element.shadowRoot;

          if (currentParent == null) {
            break;
          }
        }
      }

      return target_element;
    JS
  end

  # Generate a unique user data directory for Chrome
  # @return [String] Path to the user data directory
  def user_data_directory
    @user_data_directory ||= "/var/www/chrome-user-data/chrome-user-data-#{SecureRandom.hex(4)}"
  end

  # Clean up the user data directory
  def clean_up_user_data_directory
    FileUtils.rm_rf(user_data_directory) if File.directory?(user_data_directory)
  end
end
