# frozen_string_literal: true
require 'spec_helper'

describe Qrvey::FullDeleteWorker do
  let(:worker) { described_class.new }

  let(:metadata) { create(:account) }
  let(:metadata_class) { metadata.class.to_s }
  let(:metadata_id) { metadata.id }

  describe 'payload' do
    it 'has the intended structure' do
      allow(worker).to receive(:headers).and_return({})

      url = "https://vu8m5k5hwh.execute-api.us-east-1.amazonaws.com/Prod/v5/dataset/#{Rails.configuration.qrvey_dataset_id}/data/delete_by_query"
      payload = {
        body: {
          query: {
            term: {
              "#{Rails.configuration.qrvey_column_prefix}_#{metadata_class.underscore}_id": metadata_id
            }
          }
        }
      }.to_json
      response = { 'total' => 1, 'deleted' => 1 }.to_json

      stub = stub_request(:post, url).with(body: payload).to_return(status: 200, body: response)
      worker.perform(metadata_class, metadata_id)
      expect(stub).to have_been_requested
    end
  end

  describe 'error handling' do
    context 'when some documents could not be deleted' do
      it 'reports to Rollbar' do
        response = { 'total' => 2, 'deleted' => 1 }.to_json
        allow(worker).to receive(:send_to_open_search).and_return(response)

        expect(Rollbar).to receive(:error).once
        worker.perform(metadata_class, metadata_id)
      end
    end
  end
end
