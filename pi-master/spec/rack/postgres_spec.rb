# frozen_string_literal: true
require 'spec_helper'

describe Rack::Postgres do
  let(:mock_class) do
    Class.new do
      include Rack::Postgres

      def initialize
        postgres_connect!
      end
    end
  end

  let(:mock_instance) { mock_class.new }
  let(:mock_connection) { double('PG::Connection') }
  let(:mock_result) { double('PG::Result') }

  before do
    allow(PG).to receive(:connect).and_return(mock_connection)
  end

  describe '#postgres_execute' do
    context 'when query executes successfully' do
      before do
        allow(mock_connection).to receive(:exec).and_return(mock_result)
      end

      it 'returns the query result' do
        result = mock_instance.postgres_execute('sql')

        expect(result).to eq(mock_result)
      end
    end

    Rack::Postgres::CONNECTION_ERRORS.each_key do |error_class|
      context "when query fails due to #{error_class}" do
        before do
          allow(mock_connection).to receive(:exec).and_raise(error_class.new)
        end

        it "retries" do
          expect(PG).to receive(:connect).twice
          expect(mock_connection).to receive(:exec).twice

          mock_instance.postgres_execute('sql')
        end
      end
    end

    context 'when query fails due to other random errors' do
      before do
        allow(mock_connection).to receive(:exec).and_raise(StandardError.new)
      end

      it 'returns without a retry' do
        expect(PG).to receive(:connect).once
        expect(mock_connection).to receive(:exec).once

        mock_instance.postgres_execute('sql')
      end
    end
  end
end
