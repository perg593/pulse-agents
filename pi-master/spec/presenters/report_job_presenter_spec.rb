# frozen_string_literal: true
require 'spec_helper'

describe ReportJobPresenter do
  include Rails.application.routes.url_helpers

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, admin: true) }
  let(:survey) { create(:survey, account: account) }
  let(:survey_locale_group) { create(:survey_locale_group, account: account) }

  describe "export_jobs" do
    let(:presenter) { described_class.new(user, survey: survey) }
    let(:jobs) { presenter.export_jobs }

    before do
      create(:report_job, user: user, current_user_email: user.email, survey: survey).id
      5.times do |_|
        create(:report_job, user: user, current_user_email: user.email, survey: survey, status: :done).id
      end
      # different survey
      create(:report_job, user: user, current_user_email: user.email, survey: create(:survey, account: account))
      # different user
      create(:report_job, user: create(:user, account: account), current_user_email: user.email, survey: survey)
      # different survey locale group
      create(:report_job, user: user, current_user_email: user.email, survey_locale_group: survey_locale_group)
    end

    it "returns an array of report jobs" do
      expect(jobs.is_a?(Array)).to be true
    end

    context "when a report job finished over 7 days ago" do
      before do
        ReportJob.delete_all

        shared_user_params = {user: user, current_user_email: user.email, survey: survey, status: :done}

        create(:report_job, **shared_user_params, updated_at: Time.current)
        create(:report_job, **shared_user_params, updated_at: 7.days.ago + 1.second, created_at: 8.days.ago)

        @missing_report_job = create(:report_job, **shared_user_params, updated_at: 7.days.ago)
      end

      it "does not return report jobs completed more than 7 days ago" do
        expect(jobs.detect { |job| job["id"] == @missing_report_job.id }).to be_nil
      end
    end

    it "excludes report jobs that finished more than 7 days ago" do
      old_report_job = create(:report_job, user: user, current_user_email: user.email, survey: survey)

      expected_report_jobs = ReportJob.where(user: user, survey: survey).order(created_at: :desc).limit(5)

      expect(jobs.length).to eq 5

      jobs.each_with_index do |job, i|
        expect(job["id"]).to eq(expected_report_jobs[i].id)
      end
    end

    it "only returns report jobs for the specified survey" do
      jobs.each do |job|
        expect(ReportJob.find(job["id"]).survey.id).to eq(survey.id)
      end
    end

    it "only returns report jobs for the specified user" do
      jobs.each do |job|
        expect(ReportJob.find(job["id"]).user_id).to eq(user.id)
      end
    end

    context "when a survey locale group is provided" do
      let(:presenter) { described_class.new(user, survey_locale_group: survey_locale_group) }

      it "only returns report jobs for the specified survey locale group" do
        jobs.each do |job|
          expect(ReportJob.find(job["id"]).survey_locale_group.id).to eq(survey_locale_group.id)
        end
      end
    end
  end

  describe "export_job" do
    let(:report_job) { create(:report_job, user: user, current_user_email: user.email, survey: survey) }
    let(:presenter) { described_class.new(user) }
    let(:job) { presenter.export_job(report_job) }

    describe "response structure" do
      it "returns an object with the expected structure" do
        expect(job.keys).to match_array(%w(id status downloadUrl createdAt updatedAt emailAddress))
      end

      it "returns an object with the expected values" do
        expect(job["id"]).to eq(report_job.id)
        expect(job["status"]).to eq(report_job.status.to_s)
        expect(job["downloadUrl"]).to eq(report_job.report_url)
        expect(job["updatedAt"]).to eq(report_job.updated_at.to_i * 1000)
        expect(job["createdAt"]).to eq(report_job.created_at.to_i * 1000)
        expect(job["emailAddress"]).to eq(report_job.current_user_email)
      end
    end

    context "when the user is an admin" do
      before do
        user.update(admin: true)
      end

      it "provides updatedAt and createdAt to admins" do
        expect(job["updatedAt"]).to eq(report_job.updated_at.to_i * 1000)
        expect(job["createdAt"]).to eq(report_job.created_at.to_i * 1000)
      end
    end

    context "when the user is not an admin" do
      before do
        user.update(admin: false)
      end

      it "does not provide updatedAt and createdAt to non-admins" do
        expect(job.keys.include?("updatedAt")).to be false
        expect(job.keys.include?("createdAt")).to be false
      end
    end
  end

  describe "#report_creation_path" do
    context "when a survey is provided" do
      let(:presenter) { described_class.new(user, survey: survey) }

      it "returns a url to the report creation endpoint" do
        expect(presenter.report_creation_path).to eq report_jobs_path(survey_id: survey.id, host: "test")
      end
    end

    context "when a survey locale group is provided" do
      let(:presenter) { described_class.new(user, survey_locale_group: survey_locale_group) }

      it "returns a url to the report creation endpoint" do
        expect(presenter.report_creation_path).to eq report_jobs_path(survey_locale_group_id: survey_locale_group.id)
      end
    end
  end
end
