# frozen_string_literal: true

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength

require 'json'
require 'net/http'

require 'active_support'
require 'active_support/notifications'

require File.join(File.dirname(__FILE__), 'pi_logger')

Dir[File.join(__dir__, 'database', '*.rb')].each { |file| require file }
require File.join(File.dirname(__FILE__), 'database')

require File.join(File.dirname(__FILE__), 'sidekiq_init')
require File.join(File.dirname(__FILE__), 'common')
require File.join(File.dirname(__FILE__), 'integration_switch')
require File.join(File.dirname(__FILE__), 'influx')
require File.join(File.dirname(__FILE__), 'native_serve')
require File.join(File.dirname(__FILE__), 'email_serve')
require File.join(File.dirname(__FILE__), 'serve')
require File.join(File.dirname(__FILE__), 'direct_serve')
require File.join(File.dirname(__FILE__), 'survey_questions')
require File.join(File.dirname(__FILE__), 'submissions')
require File.join(File.dirname(__FILE__), 'present_event')
require File.join(File.dirname(__FILE__), 'present_survey')
require File.join(File.dirname(__FILE__), 'present_poll')
require File.join(File.dirname(__FILE__), 'direct_submission_tools')
require File.join(File.dirname(__FILE__), 'direct_submission')
require File.join(File.dirname(__FILE__), 'devices')
require File.join(File.dirname(__FILE__), 'results')
require File.join(File.dirname(__FILE__), 'present_results')
require File.join(File.dirname(__FILE__), 'track_event')
require File.join(File.dirname(__FILE__), 'custom_content_link_click')

module Rack
  class Pi
    include PiLogger
    include NativeServe
    include EmailServe
    include Serve
    include Postgres
    include Database
    include SidekiqInit
    include SurveyQuestions
    include Submissions
    include PresentEvent
    include PresentSurvey
    include PresentPoll
    include Devices
    include Results
    include TrackEvent
    include CustomContentLinkClick
    include Influx

    def initialize
      @environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      @hostname = `hostname`.strip
      @influxdb_batch = []

      postgres_connect!
      redis_connect!
      influxdb_connect!
      influx_thread = send_transmissions_to_influx_every_second

      Signal.trap('EXIT') { influx_thread&.exit }

      log "Initializing #{@environment} environment"
    end

    # Please update PI::Influx::clean_endpoint as well when adding an endpoint
    def call(env)
      @start_time = Time.now

      @env = env
      @params = parse_params

      res =
        case @env['REQUEST_PATH']
        when '/serve'
          serve_call
        when '/direct_serve'
          direct_serve_call
        when /^\/surveys\/([0-9]+)\/questions/
          load_survey_questions_call
        when /^\/surveys\/([0-9]+)\/poll/
          present_poll_call
        when /^\/surveys\/[0-9]+$/
          present_survey_call
        when /^\/surveys\/([-a-zA-Z0-9]+)/
          present_event_call
        when /^\/submissions\/email_answer/
          email_submissions_answer_call
        when /^\/submissions\/([-a-zA-Z0-9]+)\/answer/
          submissions_answer_call
        when /^\/submissions\/([-a-zA-Z0-9]+)\/all_answers/
          submissions_all_answers_call
        when /^\/submissions\/([-a-zA-Z0-9]+)\/viewed_at/
          submissions_viewed_at_call
        when /^\/submissions\/([-a-zA-Z0-9]+)\/close/
          submissions_close_call
        when /^\/q\/([0-9]+)/
          direct_submission_call
        when /^\/devices\/([-a-zA-Z0-9]+)\/set_data/
          device_set_data
        when '/results'
          results
        when '/present_results'
          present_results
        when '/track_event'
          track_event
        when '/custom_content_link_click'
          custom_content_link_click
        else
          heartbeat_or_not_found
        end

      log_time_influxdb(@env['REQUEST_PATH'], 'pi')

      res
    rescue StandardError => e
      unexpected_exception_handler(e)
    end

    private

    def heartbeat_or_not_found
      if @env['REQUEST_PATH'] == '/heartbeat'
        # This will get more complicated as we add more dependencies
        log "Processing #{@env['REQUEST_METHOD']} #{@env['REQUEST_PATH']}"
        heartbeat_handler
      else
        [404, {'Content-Type' => 'text/plain'}, ['Not found.']]
      end
    end

    def unexpected_exception_handler(e)
      Rollbar.error(e, request_path: @env["REQUEST_PATH"], request_params: @params) unless %w(development test).include? @environment
      log "Unexpected exception: #{e.inspect}"
      log e.backtrace.join("\n")
      jsonp_error_response(error: "#{e.inspect}\\n#{e.backtrace.join('\n')}")
    end

    def heartbeat_handler
      postgres_heartbeat
      redis_heartbeat
      log 'Pulse detected!'
      log_time
      [200, {'Content-Type' => 'text/plain'}, ['Pulse detected!']]
    rescue StandardError
      log 'No pulse! :('
      log_time
      jsonp_error_response
    end
  end
end

# rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength
