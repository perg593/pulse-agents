# frozen_string_literal: true
require 'spec_helper'

describe UpdateSubmissionViewedAtWorker do
  before do
    Sidekiq::Worker.clear_all
    Submission.delete_all
  end

  let(:submission) { create(:submission, udid: '00000000-0000-4000-f000-000000000001') }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  context 'when viewed_at is already filled' do
    let(:submission) { create(:submission, viewed_at: FFaker::Time.datetime) }

    it 'does not update submissions.viewed_at' do
      expect { described_class.new.perform(submission.udid, Time.current) }.not_to change { submission.reload.viewed_at }
    end
  end

  context "when viewed_at is after submissions.created_at" do
    let(:viewed_at) { (submission.created_at + 3.seconds).to_s }

    it "updates submissions.viewed_at" do
      described_class.new.perform(submission.udid, viewed_at)

      expect(submission.reload.viewed_at).to eq Time.parse(viewed_at)
    end
  end

  context "when viewed_at is before submissions.created_at" do
    let(:viewed_at) { (submission.created_at - 15.seconds).to_s }

    it "sets viewed_at to submission.created_at" do
      described_class.new.perform(submission.udid, viewed_at)

      expect(submission.reload.viewed_at).to eq submission.created_at
    end
  end
end
