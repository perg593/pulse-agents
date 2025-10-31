# frozen_string_literal: true

require 'spec_helper'

describe Rack::Credentials do
  it 'returns credentials' do
    expect(described_class.credentials.config.present?).to be true
  end

  it 'returns credentials for the matching environment' do
    # Rails automatically loads and decrypts "config/credentials/#{:env}.yml.enc"
    expect(described_class.credentials.config).to eq Rails.application.credentials.config
  end
end
