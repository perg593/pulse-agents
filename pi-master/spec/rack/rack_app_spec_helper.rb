# frozen_string_literal: true
module RackAppSpecHelper
  require 'net/http'

  def port
    9898
  end

  def start_rack_app
    environment = 'test'
    server = 'thin'

    ENV['SIDEKIQ_INLINE'] = 'false'

    rack_server_process = ChildProcess.build(*['rackup', '-E', environment.to_s, '-p', port.to_s, '-s', server.to_s, 'rack/config.ru'].compact)
    # rack_server_process.duplex = true
    # rack_server_process.io.stdout = $stdout
    rack_server_process.start
    # Poll the server until it's ready to accept requests
    wait_for_rack_app_to_start

    RSpec.configuration.rack_test_server = rack_server_process
  end

  def stop_rack_app
    RSpec.configuration.rack_test_server.stop
  end

  def restart_rack_app
    stop_rack_app
    start_rack_app
  end

  def wait_for_rack_app_to_start
    Retryable.with_retry(max_retry_count: 9, interval: 1) { rack_app('/heartbeat') }
  end

  def rack_app(uri, headers = {})
    Net::HTTP.start("localhost", port) do |http|
      request = Net::HTTP::Get.new uri, headers
      http.request(request)
    end
  end

  def rack_app_as_json(uri, headers = {})
    parse_json_response(rack_app(uri, headers).body)
  end

  def parse_json_response(body)
    JSON.parse(body.gsub(/^[^(]+\(/, '').gsub(/\);$/, ''))
  rescue
    raise "bad JSON response #{body}"
  end

  def enable_rack_attack
    ENV['RACK_ATTACK_ENABLED'] = 'true'
  end

  def disable_rack_attack
    ENV['RACK_ATTACK_ENABLED'] = nil
  end

  # rubocop:disable Style/HashEachMethods - Cop says :each_key should be used even though Redis class instance doesn't respond to it
  def delete_rack_attack_cache
    database_yml = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', 'config', 'database.yml'), aliases: true)
    redis = Redis.new(url: database_yml['test']['redis'])
    redis.keys.each { |key| redis.del(key) if key.include?('rack::attack') }
  end

  # TODO: test every column in #survey_columns_to_select
  # rubocop:disable Metrics/AbcSize
  def expect_survey_columns_to_select(response, survey)
    expect(response["survey"]["id"].to_i).not_to eq(0)
    expect(response["survey"]["name"]).to eq(survey.name)
    expect(response["survey"]["survey_type"].to_i).to eq(0)
    expect(response["survey"]["invitation"]).to eq("Hello, want to take a survey?")
    expect(response["survey"]["top_position"]).to eq(survey.top_position)
    expect(response["survey"]["bottom_position"]).to eq(survey.bottom_position)
    expect(response["survey"]["left_position"]).to eq(survey.left_position)
    expect(response["survey"]["right_position"]).to eq(survey.right_position)
    expect(response["survey"]["width"].to_i).to eq(300)
    expect(response["survey"]["custom_css"]).to eq(survey.custom_css)
    expect(response["survey"]["thank_you"]).to eq("*Thank you* for your feedback!")
    expect(response["survey"]["all_at_once_submit_label"]).to eq(survey.all_at_once_submit_label)
    expect(response["survey"]["all_at_once_error_text"]).to eq(survey.all_at_once_error_text)
  end

  # @param { RackSchemas } schema - A dry-schema schema
  # @param { Hash } parsed_body - The parsed json response object
  def assert_valid_schema(schema, parsed_body)
    schema_validation = schema.call(parsed_body)

    expect(schema_validation.success?).to be(true), "#{schema_validation.errors.to_h}\n\n#{parsed_body}"
  end
end
