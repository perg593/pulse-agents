# frozen_string_literal: true
require 'spec_helper'

describe NBABrazeWorker do
  let(:worker) { described_class.new }

  let(:survey) { create(:survey) }
  let(:submission) { create(:submission, survey: survey) }

  let(:valid_email_address) { FFaker::Internet.email }
  let(:expected_payload) do
    {
      attributes: [{
        external_id: valid_email_address,
        submission_udid: submission.udid
      }]
    }
  end

  it_behaves_like "braze reporter" do
    subject { described_class.new }
  end

  # TODO: Test all use cases
  it "calls braze with all required input when input is valid" do
    expect(worker).to receive(:send_to_braze).with(expected_payload)

    worker.perform("nba_test", valid_email_address, submission.udid, survey.possible_answers.last.id, nil, nil, nil)
  end

  it "works with a valid e-mail" do
    expect(worker).to receive(:send_to_braze).with(expected_payload)

    result = worker.perform("nba_test", valid_email_address, submission.udid, survey.possible_answers.last.id, nil, nil, nil)
    expect(result).to be(true)
  end

  it "rejects an invalid e-mail" do
    email_address = 'bad'.dup

    result = worker.perform("nba_test", email_address, submission.udid, survey.possible_answers.last.id, nil, nil, nil)
    expect(result).to be_nil
  end

  it "replaces inner spaces in e-mails with plus (+) signs" do
    email_address = "jonathan testing this@ekohe.com".dup

    expect(worker).to receive(:send_to_braze).with({attributes: [{ external_id: "jonathan+testing+this@ekohe.com", submission_udid: submission.udid }]})
    result = worker.perform("nba_test", email_address, submission.udid, survey.possible_answers.last.id, nil, nil, nil)

    expect(result).to be(true)
  end
end
