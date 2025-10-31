# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Rack
  module Common
    COOKIE_NAME = "pulse_insights_udid"
    COOKIE_EXPIRES = 60 # days

    def survey_host
      { development: 'localhost:3000',
        test: 'localhost:8888',
        develop: 'develop-survey.pulseinsights.com',
        staging: 'staging-survey.pulseinsights.com'
      }[@environment.to_sym]
    end

    def parse_params
      log "Processing #{@env["REQUEST_METHOD"]} #{@env["REQUEST_PATH"]} #{@env["QUERY_STRING"]}"
      params = Rack::Utils.parse_nested_query(@env["QUERY_STRING"])
      params = replace_inconvertible_characters(params)
      log "Parameters: #{params.inspect}"
      params
    end

    def replace_inconvertible_characters(object)
      case object
      when Hash
        object.transform_values! { |value| replace_inconvertible_characters(value) }
      when Array
        object.map { |value| replace_inconvertible_characters(value) }
      else
        object&.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end

    def verify_identifier
      return [] if @params["identifier"]&.size == 11

      error = "Error: Parameter 'identifier' missing"
      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end

    def verify_udid
      return [] if @params['udid']&.match?(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)

      error = "Error: Parameter 'udid' invalid"
      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end

    def verify_account(account_identifier, callback)
      @account = get_account(account_identifier)

      if @account.count.zero?
        error = "Error: Account with identifier #{account_identifier} not found"
        log error
        return [400, {'Content-Type' => 'text/plain'}, [error]]
      end

      if @account.first['enabled'] == 'f'
        error = "This account has been deactivated by the administrator."
        log "Error: #{error}"
        return jsonp_response(callback, "window.PulseInsightsObject.log(\"#{error}\")")
      end

      []
    end

    def jsonp_response(callback, javascript_object, headers = {})
      headers['Content-Type'] = callback ? 'application/javascript' : 'application/json'

      # TODO: Remove this block because console doesn't serve surveys anymore
      case `hostname`.strip
      when 'console'
        headers['Hostname'] = 'c'
      when 'survey'
        headers['Hostname'] = 's'
      end

      return [200, headers, [javascript_object]] unless callback # json

      if callback.match?(/^window\.PulseInsightsObject\.jsonpCallbacks\.request_\d+$/)
        [200, headers, ["#{callback}(#{javascript_object});"]]
      else
        [400, {'Content-Type' => 'text/plain'}, ["Error: Parameter 'callback' invalid"]]
      end
    end

    def json_response(json_object, headers = {})
      [200, { 'Content-Type' => 'application/javascript' }.merge(headers), json_object]
    end

    def jsonp_error_response(headers: {}, error: '')
      headers['Content-Type'] = 'application/javascript'

      case `hostname`.strip
      when 'console'
        headers['Hostname'] = 'c'
      when 'survey'
        headers['Hostname'] = 's'
      end

      if %w(test development).include? @environment
        [500, headers, [error]]
      else
        [500, headers, ['']]
      end
    end

    def log_time
      log "Processed in #{((Time.now - @start_time) * 1000 * 100).to_i.to_f / 100.0} ms."
    end

    def url_without_protocol(url)
      url.gsub!('file:///', 'http://domain.com/') if @environment == 'test' && url =~ /^file:\/\/\//

      md = url.match(/^(http(s?):\/\/([^\/]+))/)

      return [403, {'Content-Type' => 'text/plain'}, ['']] if md.nil?

      url.sub(/^http(s?):\/\//, '')
    end

    def verify_serve_params
      error = verify_get_survey_params
      return error if error.any?

      if @url.nil? && @params['device_type'] != "native_mobile"
        error = 'Error: HTTP_REFERER or url param missing'
        log error
        return [400, {'Content-Type' => 'text/plain'}, [error]]
      end

      error = verify_account(@params['identifier'], @params["callback"])
      return error if error.any?

      []
    end

    def serve_worker_base_params(survey_id, submission_udid, device_id)
      {
        'survey_id' => survey_id,
        'submission_udid' => submission_udid,
        'device_id' => device_id,
        'udid' => @udid,
        'ip_address' => @ip_address,
        'user_agent' => @user_agent,
        'custom_data' => @custom_data,
        'device_type' => @device_type,
        'client_key' => @client_key
      }
    end

    # Verify the params presence and validity
    #
    # > For now, those are the same rules for the generic get survey and custom-fired present surveys.
    #   I wonder if we really need udid checking for custom firing present surveys
    #
    def verify_get_survey_params
      error = verify_identifier
      return error unless error.empty?

      error = verify_device_type(@params["device_type"])
      return error unless error.empty?

      unless %w(native_mobile email).include? @params["device_type"]
        %w(callback udid).each do |p|
          next unless @params[p].nil?

          error = "Error: Parameter '#{p}' missing"
          log error
          return [400, {'Content-Type' => 'text/plain'}, [error]]
        end
      end

      []
    end

    def valid_mobile_type?(mobile_type)
      mobile_type.nil? || %w(android ios).include?(mobile_type)
    end

    def verify_mobile_type(mobile_type)
      return [] if valid_mobile_type?(mobile_type)

      error = "Error: Parameter 'mobile_type' '#{mobile_type}' is invalid"
      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end

    def valid_device_type?(device_type)
      %w(desktop mobile tablet native_mobile email).include? device_type
    end

    def verify_device_type(device_type)
      return [] if valid_device_type?(device_type)

      error = "Error: Parameter 'device_type' '#{device_type}' is invalid"
      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end

    def valid_client_key?(client_key)
      return false if client_key.nil?

      !%w(null undefined).include? client_key.strip
    end

    def verify_ip_address
      blocked_ips = @account.first['ips_to_block']
      @ip_address = @env['HTTP_X_REAL_IP']
      @preview_mode = @params['preview_mode'].nil? ? false : (@params['preview_mode'] == 'true')

      return unless ip_not_allowed(blocked_ips)

      "window.PulseInsightsObject.log(\"IP #{@ip_address} not allowed\")"
    end

    # Verify if the IP is allowed
    # Compare with the blocked IPs from the "ips_to_block" column in the 'Account' table.
    def ip_not_allowed(ips_to_block)
      return if @preview_mode
      return unless @ip_address
      return unless ips_to_block
      ip_is_blocked = false

      splitted_ips_to_block = ips_to_block.split("\n")

      splitted_ips_to_block.each do |ip_to_block|
        ip_is_blocked =
          if ip_to_block.start_with?('/') && ip_to_block.end_with?('/')
            !Regexp.new(ip_to_block[1..-2]).match(@ip_address).nil?
          else
            ip_to_block == @ip_address
          end

        if ip_is_blocked
          log "Error: IP #{@ip_address} is not allowed." if ip_is_blocked
          return true
        end
      end

      ip_is_blocked
    end

    def url_type_automation_exists?(identifier)
      res = postgres_execute(<<-SQL)
        SELECT EXISTS (
          SELECT 1
          FROM automations
          INNER JOIN accounts ON accounts.id = automations.account_id
          WHERE automations.enabled = true
            AND automations.condition_type = 1 /* 1 == "url type" */
            AND accounts.identifier = '#{identifier}'
        )
      SQL
      res.first['exists'] == 't'
    end

    # TODO: Return multiple missing parameters
    def verify_required_params(required_params)
      missing_param = required_params.detect do |required_param|
        !@params.keys.include?(required_param)
      end

      return unless missing_param

      error_message = "Error: Parameter '#{missing_param}' missing"
      log error_message
      [400, {"Content-Type" => "text/plain"}, [error_message]]
    end
  end
end
