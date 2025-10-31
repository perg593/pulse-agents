# frozen_string_literal: true
require 'spec_helper'

describe Invitation do
  before do
    described_class.delete_all
  end

  describe "expiration" do
    subject { invitation.expired? }

    let(:invitation) { create(:invitation) }

    context "when the expiration date is in the future" do
      it { is_expected.to be false }
    end

    context "when the expiration date is in the past" do
      let(:invitation) { create(:invitation, expires_at: 1.day.ago) }

      it { is_expected.to be true }
    end
  end

  describe "validations" do
    it "requires an account" do
      invitation = described_class.create(email: FFaker::Internet.email)

      expect(invitation.valid?).to be false
      expect(invitation.errors.details[:account].present?).to be true
      expect(described_class.count).to eq(0)
    end

    it "requires an e-mail" do
      invitation = described_class.create(account: create(:account))

      expect(invitation.valid?).to be false
      expect(invitation.errors.details[:email].present?).to be true
      expect(described_class.count).to eq(0)
    end

    it "requires an e-mail and an account" do
      invitation = described_class.create(email: FFaker::Internet.email, account: create(:account))

      expect(invitation.valid?).to be true
      expect(described_class.count).to eq(1)
    end

    it "rejects invalid e-mail addresses" do
      invalid_addresses = [nil, "", " ", "ekohe.com"]

      invalid_addresses.each do |invalid_address|
        invitation = described_class.create(account: create(:account), email: invalid_address)

        expect(invitation.valid?).to be false
        expect(invitation.errors.details[:email].present?).to be true
        expect(described_class.count).to eq(0)
      end
    end

    it "rejects an e-mail address belonging to an existing user" do
      existing_user = create(:user)

      invitation = described_class.create(account: create(:account), email: existing_user.email)

      expect(invitation.valid?).to be false
      expect(invitation.errors.details[:email].present?).to be true
      expect(described_class.count).to eq(0)
    end

    it "rejects invalid user levels" do
      [-1, 42].each do |invalid_level|
        invitation = described_class.create(email: FFaker::Internet.email, account: create(:account), level: invalid_level)
        expect(invitation.valid?).to be false
        expect(invitation.errors.details[:level].present?).to be true
        expect(described_class.count).to eq(0)
      end
    end

    it "requires a user level" do
      invitation = described_class.create(account: create(:account), level: nil)

      expect(invitation.valid?).to be false
      expect(invitation.errors.details[:level].present?).to be true
      expect(described_class.count).to eq(0)
    end
  end

  it "generates a token" do
    invitation = described_class.create(email: FFaker::Internet.email, account: create(:account))
    expect(invitation.token.present?).to be(true)
  end
end
