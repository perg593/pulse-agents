# frozen_string_literal: true
require 'spec_helper'

describe NBAFavouritePlayersWorker do
  let(:valid_email_address) { FFaker::Internet.email }
  let(:worker) { described_class.new }
  let(:submission_udid) { '00000000-0000-4000-f000-000000000001' }
  let(:favourite_player_names) { ["Michael Jordan", "Shaquille O'Neil"] }

  def expected_payload(email_address = valid_email_address)
    {
      attributes: [{
        external_id: email_address,
        submission_udid: submission_udid,
        pulse_favoritePlayer: favourite_player_names
      }]
    }
  end

  it_behaves_like "braze reporter" do
    subject { worker }
  end

  it "calls braze with all required input when input is valid" do
    expect(worker).to receive(:send_to_braze).with(expected_payload)

    worker.perform(valid_email_address, favourite_player_names, submission_udid)
  end

  describe "e-mail address validation" do
    it "works with a valid e-mail" do
      expect(worker).to receive(:send_to_braze).with(expected_payload)

      worker.perform(valid_email_address, favourite_player_names, submission_udid)
    end

    it "rejects an invalid e-mail" do
      email_address = "bad"

      expect(worker).not_to receive(:send_to_braze)
      worker.perform(email_address, favourite_player_names, submission_udid)
    end

    it "replaces inner spaces in e-mails with plus (+) signs" do
      email_address = "jonathan testing this@ekohe.com"

      expect(worker).to receive(:send_to_braze).with(expected_payload(email_address.gsub(" ", "+")))
      worker.perform(email_address, favourite_player_names, submission_udid)
    end
  end
end
