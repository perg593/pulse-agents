# frozen_string_literal: true
require 'rack'
require File.join(File.dirname(__FILE__), 'pi')
require File.join(File.dirname(__FILE__), 'credentials')
require File.join(File.dirname(__FILE__), 'integration_switch')

require 'ipaddr'
require 'redis'

# Sidekiq::Web configuration
require 'securerandom'
require 'sidekiq/web'
require 'sidekiq-scheduler'
require 'sidekiq-scheduler/web'

credentials = Rack::Credentials.credentials
environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
sidekiq = credentials[:sidekiq]

if sidekiq
  secret_key = SecureRandom.hex(32)
  use Rack::Session::Cookie, secret: secret_key, same_site: true, max_age: 86400

  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    username == sidekiq[:username] && password == sidekiq[:password]
  end
end

# Rollbar configuration
require 'rollbar'

Rollbar.configure do |config|
  config.access_token = credentials[:rollbar][:token]
  config.environment = environment
  config.enabled = Rack::IntegrationSwitch.integration_enabled?('rollbar')
end

# Rack::Attack configuration
require "rack/attack"
use Rack::Attack

Rack::Attack.enabled = Rack::IntegrationSwitch.integration_enabled?('rack_attack')

database_yml = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'database.yml'), aliases: true)
Rack::Attack.cache.store = Redis.new(url: database_yml[environment]['redis'])

# TODO: testing
safe_ips = [
  "10.51.48.201", # BobCat https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1905
  "10.144.11.140", # Verizon https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1985
  "157.49.229.64", "216.165.0.0/17", "216.120.156.0/22", # NYU Langone
  "69.172.159.171", # Masa
  "73.38.187.176",  # Brooke
  "98.38.62.152",   # Summer
  "108.27.18.112",  # Bieger
  "204.57.30.222",  # Dave
  "71.234.255.73",  # Tim
  "108.26.193.113", # JD
  "73.65.171.88",   # Pablo
  "46.75.203.0"     # Jonny
].freeze

# TODO: testing
safe_referers = [
  'stage.chat.benjaminmoore.com', # Benjamin Moore https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1982
  'chat.benjaminmoore.com' # Benjamin Moore https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1982
].freeze

# TODO: testing
Rack::Attack.safelist('allow whitelisted ips') do |request|
  safe_ips.any? do |safe_ip|
    range = IPAddr.new(safe_ip)

    range.include?(request.ip)
  end
end

# TODO: testing
Rack::Attack.safelist('allow whitelisted referers') do |req|
  safe_referers.any? { |safe_referer| req.referer&.include?(safe_referer) }
end

Rack::Attack.blocklist('allow2ban bots') do |req|
  from_mobile_app = Rack::Utils.parse_nested_query(req.env["QUERY_STRING"])["device_type"] == "native_mobile"

  max_attempts =
    if from_mobile_app
      500
    elsif req.ip.start_with? '136.226.244.' # Zscaler https://ekohe.slack.com/archives/C027RQYJG/p1756417379856959
      200
    else
      100
    end

  # max_attempts "serve" requests per day. Released after 24 hours
  Rack::Attack::Allow2Ban.filter(req.ip, maxretry: max_attempts, findtime: 86400, bantime: 86400) { req.path.include?('serve') }
end

run Rack::URLMap.new('/' => Rack::Pi.new, '/sidekiq' => Sidekiq::Web)
