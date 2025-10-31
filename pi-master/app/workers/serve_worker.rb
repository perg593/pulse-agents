# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

# This worker will perform the following tasks:
# - Update 'account calls count' and 'last call at'
# - Create 'device' if needed
# - Create impression

class ServeWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(params)
    @survey_id       = params['survey_id']
    @submission_udid = params['submission_udid']
    @device_id       = params['device_id']
    @udid            = params['udid']
    @url             = params['url']
    @ip_address      = params['ip_address']
    @user_agent      = params['user_agent']
    @custom_data     = params['custom_data']
    @device_type     = params['device_type'] || ''
    @visit_count     = params['visit_count']
    @pageview_count  = params['pageview_count']
    @client_key      = params['client_key']
    @pseudo_event    = params['pseudo_event']

    if @device_id
      @device = { id: @device_id.to_i, udid: @udid, client_key: @client_key }
      UpdateClientKeyWorker.new.perform(@device_id, @client_key) if @client_key
    else
      @device = CreateDeviceWorker.new.perform(@udid, @client_key)
    end

    CreateImpressionWorker.new.perform(create_impression_worker_params)
  end

  private

  def create_impression_worker_params
    {
      'survey_id'       => @survey_id,
      'device'          => @device,
      'udid'            => @submission_udid,
      'url'             => @url,
      'ip_address'      => @ip_address,
      'user_agent'      => @user_agent,
      'custom_data'     => @custom_data,
      'device_type'     => @device_type,
      'visit_count'     => @visit_count,
      'pageview_count'  => @pageview_count,
      'client_key'      => @client_key,
      'pseudo_event'    => @pseudo_event
    }
  end
end
