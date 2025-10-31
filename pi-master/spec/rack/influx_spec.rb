# frozen_string_literal: true

require 'spec_helper'

describe Rack::Influx do
  include described_class

  describe '#clean_identifier' do
    context 'with valid identifier' do
      let(:identifier) { 'PI-12345678' }

      it 'returns the identifier' do
        expect(clean_identifier(identifier)).to eq identifier
      end
    end

    context 'with invalid identifier' do
      context 'with a single line' do
        let(:identifier) { 'PI-12345678 12345678' }

        it 'returns "other"' do
          expect(clean_identifier(identifier)).to eq 'other'
        end
      end

      context 'with multiple lines' do
        let(:identifier) { "PI-12345678\n12345678" }

        it 'returns "other"' do
          expect(clean_identifier(identifier)).to eq 'other'
        end
      end
    end
  end
end
