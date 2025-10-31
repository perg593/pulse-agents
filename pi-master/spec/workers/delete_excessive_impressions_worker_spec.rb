# frozen_string_literal: true

require 'spec_helper'

describe DeleteExcessiveImpressionsWorker do
  before do
    Sidekiq::Worker.clear_all
    Account.delete_all
    Survey.delete_all
    Device.delete_all
    Submission.delete_all
  end

  context 'when device does not exist' do
    let(:device_id) { 0 }

    # Deliberately testing early return to avoid invalid queries taking up server resources
    it 'exits the worker' do
      worker = described_class.new

      expect(worker).not_to receive(:excessive_impressions_exist?)

      described_class.new.perform(device_id)
    end
  end

  describe "excessive impression deletion" do
    let(:device) { create(:device) }
    let(:survey) { create(:survey) }

    before do
      15.times { create(:submission, survey: survey, device: device, answers_count: 0, viewed_at: 0) }            # Impression
      10.times { create(:submission, survey: survey, device: device, answers_count: 0, viewed_at: Time.current) } # Viewed Impression
      10.times { create(:submission, survey: survey, device: device, answers_count: 1) }                          # Submission
    end

    context "when there aren't excessive impressions" do
      it "deletes no impression" do
        expect { described_class.new.perform(device.id) }.not_to change { device.submissions.count }
      end
    end

    context "when there are excessive impressions" do
      let(:impression_limit) { 10 }

      before do
        stub_const('DeleteExcessiveImpressionsWorker::IMPRESSION_LIMIT_PER_DEVICE', impression_limit)
      end

      it "deletes them to half the limit" do
        impressions = device.submissions.where(answers_count: 0, viewed_at: nil)
        expect { described_class.new.perform(device.id) }.to change { impressions.count }.from(15).to(impression_limit / 2)
      end

      it "doesn't delete viewed impressions" do
        viewed_impressions = survey.submissions.where(answers_count: 0).where.not(viewed_at: nil)
        expect { described_class.new.perform(device.id) }.not_to change { viewed_impressions.count }
      end

      it "doesn't delete submissions" do
        submissions = survey.submissions.where(answers_count: 1)
        expect { described_class.new.perform(device.id) }.not_to change { submissions.count }
      end
    end
  end
end
