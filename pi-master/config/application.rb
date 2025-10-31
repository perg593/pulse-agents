require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "active_storage/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

begin
  CUSTOMS = File.open(File.expand_path('../customs.yml', __FILE__)) { |file| YAML.load(file) }
rescue LoadError
  puts e.message
  puts "config/customs.yml is not configured!"
end

QRVEY_CONFIG = File.open(File.expand_path('../qrvey.yml', __FILE__)) { |file| YAML.load(file) }
AZURITY_CONFIG = File.open(File.expand_path('../azurity.yml', __FILE__)) { |file| YAML.load(file) }
CROCS_CONFIG = File.open(File.expand_path('../crocs.yml', __FILE__)) { |file| YAML.load(file) }

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PulseInsights
  class Application < Rails::Application
    config.load_defaults 6.1
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.assets.enabled = true
    config.assets.version = '1.0'

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.paths.add "app/models/validators"
    config.autoload_paths += Dir["#{Rails.root}/app/models/validators"]
    config.autoload_paths += Dir["#{Rails.root}/app/models/locale_groups"]
    config.autoload_paths += Dir["#{Rails.root}/app/models/qrvey"]
    config.autoload_paths += Dir["#{Rails.root}/app/models/triggers"]
    config.autoload_paths += Dir["#{Rails.root}/app/presenters"]

    config.exceptions_app = self.routes

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.active_record.schema_format = :sql

    config.action_mailer.delivery_method = Rails.application.credentials.mailer[:delivery_method]
    config.action_mailer.default_url_options = Rails.application.credentials.mailer[:default_url_options]
    config.action_mailer.default_options = { from: Rails.application.credentials.mailer[:mailer_sender] }
    config.action_mailer.preview_path = "#{Rails.root}/test/mailers/previews"

    # Prepend all log lines with the following tags.
    config.log_tags = [ :request_id ]

    # Change the return value of `ActionDispatch::Response#content_type` to Content-Type header without modification.
    config.action_dispatch.return_only_media_type_on_content_type = false
  end
end
