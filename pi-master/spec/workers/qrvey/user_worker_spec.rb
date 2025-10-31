# frozen_string_literal: true
require 'spec_helper'
require_relative "../../../lib/qrvey_client/qrvey_client"

describe Qrvey::UserWorker do
  before do
    account = create(:account)
    account.register_with_qrvey

    @qrvey_user = account.reload.qrvey_user
    allow(QrveyUser).to receive(:find).with(@qrvey_user.id).and_return(@qrvey_user)
    # It's a complicated method that makes API calls that I'd rather not run in this test
    allow(@qrvey_user).to receive(:register_with_qrvey)

    described_class.new.perform(@qrvey_user.id)
  end

  # rubocop:disable RSpec/MessageSpies
  # Our tests look a lot nicer when we can separate setup from assertions
  it "calls :register_with_qrvey on the QrveyUser with the provided ID" do
    # Confirm that complicated function is called.
    expect(@qrvey_user).to have_received(:register_with_qrvey).exactly(1).times
  end

  it "creates a QrveyApplication record" do
    expect(QrveyApplication.count).to eq 1
    expect(QrveyApplication.first.qrvey_user_id).to eq @qrvey_user.id
  end

  context "when run a second time" do
    before do
      described_class.new.perform(@qrvey_user.id)
    end

    it "does not create a second QrveyApplication record" do
      expect(QrveyApplication.count).to eq 1
    end
  end
end
