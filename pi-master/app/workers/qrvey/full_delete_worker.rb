# frozen_string_literal: true

# This worker directly deletes documents from OpenSearch when a specific combination of class and ID matches
module Qrvey
  class FullDeleteWorker
    include Sidekiq::Worker
    include Common

    def perform(metadata_class, metadata_id)
      @metadata_class = metadata_class
      @metadata_id = metadata_id
      tagged_logger.info "Class: #{@metadata_class}, ID: #{@metadata_id}"

      res = send_to_open_search
      res = JSON.parse(res)
      tagged_logger.info "Result: #{res}"

      return if res['total'] == res['deleted']
      Rollbar.error('Qrvey - failed to delete some documents', metadata_class: @metadata_class, metadata_id: @metadata_id, total: res['total'], deleted: res['deleted'])
    end

    def send_to_open_search
      Retryable.with_retry(interval: 5) do
        RestClient::Request.execute(method: :post, url: open_search_endpoint, payload: payload, headers: headers, log: tagged_logger)
      end
    end

    def open_search_endpoint
      "https://vu8m5k5hwh.execute-api.us-east-1.amazonaws.com/Prod/v5/dataset/#{Rails.configuration.qrvey_dataset_id}/data/delete_by_query"
    end

    def headers
      { 'x-api-key': Rails.application.credentials[:qrvey][:api_key], 'content_type': 'application/json' }
    end

    # Payload structure: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/query-dsl-term-query.html
    def payload
      { body: { query: { term: { "#{Rails.configuration.qrvey_column_prefix}_#{@metadata_class.underscore}_id": @metadata_id } } } }.to_json
    end
  end
end
