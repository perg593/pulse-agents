# frozen_string_literal: true
require 'spec_helper'

describe AccountUser do
  before do
    described_class.delete_all
    User.delete_all
    Account.delete_all
  end

  it "is created automatically when a user is created" do
    create(:user)
    expect(described_class.count).to eq(1)
  end

  it "is destroyed automatically when its corresponding user is destroyed" do
    create(:user)
    expect(described_class.count).to eq(1)

    User.first.destroy
    expect(described_class.count).to eq(0)
  end

  it "is destroyed automatically when its corresponding account is destroyed" do
    create(:user)
    expect(described_class.count).to eq(1)

    Account.first.destroy
    expect(described_class.count).to eq(0)
  end
end
