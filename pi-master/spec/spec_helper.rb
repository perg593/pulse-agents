# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'selenium-webdriver'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

# Load helpers
require 'support/controller_helpers'
require 'rack/rack_app_spec_helper'
include RackAppSpecHelper

RSpec.configure do |config|
  # Not an approved use of add_setting, but until Rspec supports around(:suite)
  # hooks, it's the best we've got.
  # https://stackoverflow.com/questions/5312333/rspec-2-beforesuite-variable-scope
  config.add_setting :rack_test_server

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # https://relishapp.com/rspec/rspec-rails/v/3-8/docs/file-fixture
  config.file_fixture_path = 'spec/file_fixtures'

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # https://relishapp.com/rspec/rspec-rails/v/3-9/docs/upgrade#file-type-inference-disabled
  config.infer_spec_type_from_file_location!

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryBot::Syntax::Methods
  config.include ControllerHelpers, :type => :controller
  config.include Devise::Test::ControllerHelpers, :type => :controller

  config.before(:suite) do
    DatabaseRewinder.clean_all

    WebMock.globally_stub_request do |request|
      if request.uri.to_s =~ /influxdb:8086/
        { status: 200, body: "", headers: {} }
      end
    end

    start_rack_app
  end

  config.after(:each) do
    DatabaseRewinder.clean

    # TODO: Put files "uploaded" in specs in one place
    ["/public/background", "/public/images", "/public/system"].each do |filepath|
      FileUtils.rm_rf(Dir["#{Rails.root}#{filepath}"])
    end

    FFaker::UniqueUtils.clear
  end

  config.after(:suite) do
    stop_rack_app
  end

  config.define_derived_metadata(file_path: Regexp.new('/spec/surveys/')) do |metadata|
    metadata[:type] = :end_to_end
  end

  config.before(:all, type: :end_to_end) { @server = start_rails_server }
  config.after(:all, type: :end_to_end) { stop_rails_server(@server) }
  config.after(:each, type: :end_to_end) do |example|
    if example.exception
      exception_formatter = configure_end_to_end_reporter
      exception_formatter.example_failed(example)
    end

    @driver&.quit
    @driver = nil
  end

  config.define_derived_metadata(file_path: Regexp.new('/spec/live_survey_tests/')) do |metadata|
    metadata[:type] = :live_survey
  end

  config.before(:all, type: :live_survey) { @snapshot_counter = 0 }
  config.after(:each, type: :live_survey) { driver.close }

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end

# Not sure why it's needed to do that, should be done automatically
# FactoryBot.find_definitions

# Delete all accounts previously created
Account.delete_all
User.delete_all
Invitation.delete_all
Device.delete_all
Submission.delete_all

def json_response
  JSON.parse(response.body)
rescue
  raise "bad JSON response #{response.body}"
end

def expect_redirected_to_dashboard
  expect(response.code).to eq("302")
  expect(response.headers["Location"]).to eq(dashboard_url)
end

def it_succeeds_with_json_response
  expect(response.code).to eq("200")
  expect(response['Content-Type']).to eq("application/json; charset=utf-8")
end

def assert_valid_schema(schema, parsed_body)
  schema_validation = schema.call(parsed_body)

  expect(schema_validation.success?).to be(true), "#{schema_validation.errors.to_h}\n\n#{parsed_body}"
end

FreeTextResponseAppliedTagSchema = Dry::Schema.JSON do
  required(:appliedTagId).value(:integer)
  required(:tagApproved).value(:bool)
  required(:tagColor).value(:string)
  required(:tagId).value(:integer)
  required(:text).value(:string)
end

def configure_end_to_end_reporter
  exception_formatter = DetailedFailureFormatter.new($stdout)

  # Confirm that the rack app process exists and is running
  exception_formatter.add_info({rack_app_pid: `ps aux | grep rackup | grep -v grep`})

  # Confirm that we can connect to the rack app
  exception_formatter.add_info({rack_app_response: `curl -s http://localhost:9898/heartbeat`})

  # Confirm that we can find surveys.js via HTTP?
  exception_formatter.add_info({surveys_js: `curl -I http://localhost:8888/assets/surveys.js`})

  exception_formatter.add_info({driver: @driver})
  exception_formatter.add_info({page_source: @driver&.page_source})

  # Confirm existence of surveys.js on page
  exception_formatter.add_info({surveys_js: @driver&.execute_script("return typeof PulseInsightsObject == 'object' && typeof pi == 'function'")})

  scripts = @driver&.execute_script(<<-JS)
          var scripts = Array.from(document.getElementsByTagName('script'));
          return scripts.map((script) => [script.src, script.readyState]);
  JS

  exception_formatter.add_info({scripts: scripts})

  widget_logs = @driver&.execute_script("return window.PulseInsightsObject.logMessages;")
  exception_formatter.add_info({widget_logs: widget_logs})

  exception_formatter.add_info({db_counts: {accounts: Account.count, surveys: Survey.count, questions: Question.count, answers: Answer.count}})

  exception_formatter.add_info({db_details: {accounts: Account.all.map(&:attributes), surveys: Survey.all.map(&:attributes), questions: Question.all.map(&:attributes)}})

  exception_formatter
end
