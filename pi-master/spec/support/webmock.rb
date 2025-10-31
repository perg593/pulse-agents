# frozen_string_literal: true

# Allows webmock to operate in cooperation with rspec.
require 'webmock/rspec'

# Allow outgoing HTTP requests for certain domains
WHITELIST = [
  "chromedriver.storage.googleapis.com" # For automated webdriver updates
].freeze

allowed_sites = lambda do |uri|
  WHITELIST.any? { |site| uri.host.include?(site) }
end

# Disable outgoing HTTP requests (only allow requests to localhost)
WebMock.disable_net_connect!(allow_localhost: true, net_http_connect_on_start: true, allow: allowed_sites)
