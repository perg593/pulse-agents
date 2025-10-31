# frozen_string_literal: true
require 'spec_helper'

describe NBABrazeCommon do
  describe "e-mail validation" do
    it "returns true for a valid e-mail address" do
      email_address = FFaker::Internet.email
      valid = described_class.valid_email_address?(email_address)
      expect(valid).to be true
    end

    it "returns true for aliased addresses" do
      ["jonathan+pulseinsights@ekohe.com", "jonathan.pulse.insights@ekohe.com"].each do |aliased_email_address|
        valid = described_class.valid_email_address?(aliased_email_address)
        expect(valid).to be true
      end
    end

    it "returns false for invalid e-mail addresses" do
      [nil, " ", "jonathan@", "test", "jonathan@test+failure.com"].each do |invalid_email_address|
        valid = described_class.valid_email_address?(invalid_email_address)
        expect(valid).to be false
      end
    end
  end

  describe "e-mail cleaning" do
    it "removes all surrounding whitespace from e-mail addresses" do
      input_email_address = " jonathan@ekohe.com "
      cleaned_email_address = described_class.clean_email_address(input_email_address)
      expect(cleaned_email_address).to eq "jonathan@ekohe.com"
    end

    it "replaces inner spaces with + signs" do
      input_email_address = "jonathan testing something@ekohe.com"
      cleaned_email_address = described_class.clean_email_address(input_email_address)
      expect(cleaned_email_address).to eq "jonathan+testing+something@ekohe.com"
    end
  end

  it_behaves_like "braze reporter" do
    subject { Class.new.extend(described_class) }
  end
end
