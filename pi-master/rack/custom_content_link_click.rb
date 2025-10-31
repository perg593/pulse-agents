# frozen_string_literal: true

require File.join(File.dirname(__FILE__), '../app/workers/create_custom_content_link_click_worker')

module Rack
  module CustomContentLinkClick
    include Common

    def custom_content_link_click
      error = verify_custom_content_link_click_params
      return error unless error.empty?

      CreateCustomContentLinkClickWorker.perform_async(@params['submission_udid'], @params['question_id'], @params['link_identifier'],
                                                       @params['client_key'], @params['custom_data'])

      jsonp_response @params['callback'], '{}'
    end

    def verify_custom_content_link_click_params
      properties = %w(submission_udid question_id link_identifier)
      error = properties.map { |prop| "Error: Parameter '#{prop}' missing" if @params[prop].nil? || @params[prop].empty? }.compact
      return [] if error.empty?

      log error
      [400, {'Content-Type' => 'text/plain'}, [error]]
    end
  end
end
