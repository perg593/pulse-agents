# frozen_string_literal: true
require "spec_helper"

describe CompleteExpiredSurveysWorker do
  let(:account) { create(:account) }

  context "with live survey that has expired" do
    let!(:survey) { create(:survey, account: account, status: :live, ends_at: 1.hour.ago) }

    it "marks the survey as complete" do
      described_class.new.perform

      survey.reload
      expect(survey.status).to eq "complete"
    end

    it "sends an e-mail notifying the survey owner" do
      expect(SurveyMailer).to receive(:survey_reached_end_date_email).with(survey.id)

      described_class.new.perform
    end
  end

  context "with live survey that has not expired" do
    let!(:survey) { create(:survey, account: account, status: :live, ends_at: 1.hour.from_now) }

    it "does not mark the survey as complete" do
      described_class.new.perform

      survey.reload
      expect(survey.status).to eq "live"
    end

    it "does not send an e-mail notifying the survey owner" do
      expect(SurveyMailer).not_to receive(:survey_reached_end_date_email).with(survey.id)

      described_class.new.perform
    end
  end

  context "with live survey that has no end date" do
    let!(:survey) { create(:survey, account: account, status: :live, ends_at: nil) }

    it "does not mark the survey as complete" do
      described_class.new.perform

      survey.reload
      expect(survey.status).to eq "live"
    end
  end

  context "with non-live survey that has expired" do
    let!(:survey) { create(:survey, account: account, status: :draft, ends_at: 1.hour.ago) }

    it "does not mark the survey as complete" do
      described_class.new.perform

      survey.reload
      expect(survey.status).to eq "draft"
    end
  end

  context "with multiple expired surveys" do
    let!(:first_survey) { create(:survey, account: account, status: :live, ends_at: 1.hour.ago) }
    let!(:second_survey) { create(:survey, account: account, status: :live, ends_at: 2.hours.ago) }
    let!(:third_survey) { create(:survey, account: account, status: :live, ends_at: 1.hour.from_now) }

    it "marks only expired surveys as complete" do
      described_class.new.perform

      first_survey.reload
      second_survey.reload
      third_survey.reload

      expect(first_survey.status).to eq "complete"
      expect(second_survey.status).to eq "complete"
      expect(third_survey.status).to eq "live"
    end
  end

  context "with survey that expires exactly at current time" do
    let!(:survey) { create(:survey, account: account, status: :live, ends_at: Time.current) }

    it "marks the survey as complete" do
      described_class.new.perform

      survey.reload
      expect(survey.status).to eq "complete"
    end
  end
end
