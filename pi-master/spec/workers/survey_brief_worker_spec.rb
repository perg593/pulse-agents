# frozen_string_literal: true
require 'spec_helper'

describe SurveyBriefWorker do
  describe "changes to survey_brief_job" do
    let(:survey_brief_job) { create(:survey_brief_job, survey: create(:survey)) }
    let(:sample_brief) { "This survey will solve all your company's problems." }
    let(:sample_input) { "This is the configuration for a survey that is running on a website..." }

    before do
      survey_brief_generator_double = instance_double(SurveyBriefGenerator)
      # rubocop:disable RSpec/ReceiveMessages
      # We can't satisfy this because we need to specify return values
      allow(survey_brief_generator_double).to receive(:generate).and_return(sample_brief)
      allow(survey_brief_generator_double).to receive(:prompt).and_return(sample_input)

      allow(SurveyBriefGenerator).to receive(:new).and_return(survey_brief_generator_double)

      # I want to confirm that we're calling SurveyBriefGenerator with the correct input.
      # rubocop:disable RSpec/ExpectInHook
      expect(SurveyBriefGenerator).to receive(:new).with(survey_brief_job.survey)

      described_class.new.perform(survey_brief_job.id)
      survey_brief_job.reload
    end

    it "sets the record to in_progress" do
      expect(survey_brief_job.audits.changes_attribute_to(:status, SurveyBriefJob.statuses[:in_progress])).to exist
    end

    it "sets the record to done" do
      expect(survey_brief_job.done?).to be true
    end

    it "stores the brief in survey_brief_job" do
      expect(survey_brief_job.brief).to eq(sample_brief)
    end

    it "stores the input in survey_brief_job" do
      expect(survey_brief_job.input).to eq(sample_input)
    end
  end

  SurveyBriefJob.statuses.keys.reject { |status| status == "pending" }.each do |status|
    context "when the survey brief job is #{status} and not pending" do
      let(:survey_brief_job) { create(:survey_brief_job, status: status, survey: create(:survey)) }

      before do
        described_class.new.perform(survey_brief_job.id)
        survey_brief_job.reload
      end

      it "does not change the job's status" do
        expect(survey_brief_job.reload.status).to eq(status.to_s)
      end
    end
  end

  context "when it fails" do
    let(:survey_brief_job) { create(:survey_brief_job, survey: create(:survey)) }

    before do
      allow(SurveyBriefGenerator).to receive(:new).and_raise('error')

      described_class.new.perform(survey_brief_job.id)
    end

    it "marks the record as failed" do
      expect(survey_brief_job.reload.status).to eq("failed")
    end
  end
end
