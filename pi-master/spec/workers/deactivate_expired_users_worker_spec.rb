# frozen_string_literal: true
require "spec_helper"

RSpec.describe DeactivateExpiredUsersWorker do
  let(:password) { "Lewis123@" }

  context "with user last signed in over 6 months ago" do
    let!(:user) { create(:user, last_sign_in_at: 7.months.ago, password: password, password_confirmation: password) }

    it "deactivates the user" do
      described_class.new.perform

      user.reload
      expect(user.active).to be false
      expect(user.valid_password?(password)).to be false
    end
  end

  context "with user last signed in within 6 months" do
    let!(:user) { create(:user, last_sign_in_at: 5.months.ago, password: password, password_confirmation: password) }

    it "does not deactivate the user" do
      described_class.new.perform

      user.reload
      expect(user.active).to be true
      expect(user.valid_password?(password)).to be true
    end
  end

  context "with user created over 6 months ago but never signed in" do
    let!(:user) { create(:user, last_sign_in_at: nil, created_at: 12.months.ago, password: password, password_confirmation: password) }

    it "deactivates the user" do
      described_class.new.perform

      user.reload
      expect(user.active).to be false
      expect(user.valid_password?(password)).to be false
    end
  end

  context "with user created in 6 months but never signed in" do
    let!(:user) { create(:user, last_sign_in_at: nil, created_at: 3.months.ago, password: password, password_confirmation: password) }

    it "does not deactivate the user" do
      described_class.new.perform

      user.reload
      expect(user.active).to be true
      expect(user.valid_password?(password)).to be true
    end
  end
end
