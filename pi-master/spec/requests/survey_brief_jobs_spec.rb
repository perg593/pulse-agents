# frozen_string_literal: true
require 'spec_helper'

describe "SurveyBriefJobs" do
  include Devise::Test::IntegrationHelpers

  describe "GET /survey_brief_job/:id" do
    let(:brief_input) { "Prompt, which includes survey context." }
    let(:survey_brief) { "AI-generated survey brief explaining this survey's purpose." }
    let(:survey) { create(:survey) }
    let(:user) { create(:user, account: survey.account) }

    context "when the user is not signed in" do
      let(:survey_brief_job) { create(:survey_brief_job, status: :done, survey: survey, input: brief_input, brief: survey_brief) }

      before do
        get survey_brief_job_path(id: survey_brief_job.id)
      end

      it "redirects to the sign in page" do
        assert_redirected_to sign_in_path
      end
    end

    context "when the user is signed in" do
      before do
        sign_in user
      end

      context "when the user is not a member of the account" do
        let(:user) { create(:user) }

        let(:survey_brief_job) { create(:survey_brief_job, status: :done, survey: survey, input: brief_input, brief: survey_brief) }

        before do
          get survey_brief_job_path(id: survey_brief_job.id), xhr: true
        end

        it "returns 404" do
          assert_response 404
        end
      end

      context "when the user is a member of the account" do
        context "when the survey_brief_job is 'done'" do
          let(:survey_brief_job) { create(:survey_brief_job, status: :done, survey: survey, input: brief_input, brief: survey_brief) }

          before do
            get survey_brief_job_path(id: survey_brief_job.id)
          end

          it "returns 200" do
            assert_response :ok
          end

          it "returns the survey brief job" do
            json_response = JSON.parse(response.body)

            expect(json_response.keys).to match_array %w(brief status)

            expect(json_response["brief"]).to eq survey_brief
            expect(json_response["status"]).to eq "done"
          end
        end

        context "when the survey_brief_job is 'in_progress'" do
          let(:survey_brief_job) { create(:survey_brief_job, status: :in_progress, survey: survey, input: brief_input) }

          before do
            get survey_brief_job_path(id: survey_brief_job.id)
          end

          it "returns 200" do
            assert_response :ok
          end

          it "returns the survey brief job" do
            json_response = JSON.parse(response.body)

            expect(json_response.keys).to match_array %w(brief status)

            expect(json_response["brief"]).to be_nil
            expect(json_response["status"]).to eq "in_progress"
          end
        end

        context "when the survey_brief_job is 'pending'" do
          let(:survey_brief_job) { create(:survey_brief_job, survey: survey, input: brief_input) }

          before do
            get survey_brief_job_path(id: survey_brief_job.id)
          end

          it "returns 200" do
            assert_response :ok
          end

          it "returns the survey brief job" do
            json_response = JSON.parse(response.body)

            expect(json_response.keys).to match_array %w(brief status)

            expect(json_response["brief"]).to be_nil
            expect(json_response["status"]).to eq "pending"
          end
        end
      end
    end
  end

  describe "POST /survey_brief_jobs" do
    let(:account) { create(:account, survey_brief_agent_enabled: true) }
    let(:survey) { create(:survey, account: account) }
    let(:user) { create(:user, account: account) }

    context "when not signed in" do
      it "returns 302" do
        post survey_brief_jobs_path(survey_brief_job: { survey_id: survey.id })

        assert_response 302
      end
    end

    context "when the record is invalid" do
      before do
        sign_in user

        create(:survey_brief_job, survey: survey)

        post survey_brief_jobs_path(survey_brief_job: { survey_id: survey.id })
      end

      it "returns 422" do
        assert_response 422
      end
    end

    context "when signed in" do
      before do
        sign_in user

        post survey_brief_jobs_path(survey_brief_job: { survey_id: survey.id })
      end

      context "when not a member of the account" do
        let(:user) { create(:user) }

        it "returns 403" do
          assert_response 403
        end
      end

      context "when not a full access member of the account" do
        let(:user) { create(:user, account: account, level: :reporting) }

        it "returns 403" do
          assert_response 403
        end
      end

      context "when a full access member of the account and signed in" do
        let(:account) { create(:account, survey_brief_agent_enabled: true) }

        it "returns 200" do
          assert_response :ok
        end

        it "creates a new survey_brief_job" do
          expect(SurveyBriefJob.count).to eq 1

          survey_brief_job = SurveyBriefJob.first

          expect(JSON.parse(response.body)["id"]).to eq survey_brief_job.id

          expect(survey_brief_job.survey_id).to eq survey.id
          expect(survey_brief_job.status).to eq "pending"
          expect(survey_brief_job.input).to be_nil
          expect(survey_brief_job.brief).to be_nil
        end

        it "queues a SurveyBriefWorker job" do
          expect(SurveyBriefWorker).to have_enqueued_sidekiq_job(SurveyBriefJob.first.id)
        end

        context "when the feature is not enabled" do
          let(:account) { create(:account, survey_brief_agent_enabled: false) }

          it "returns 403" do
            assert_response 403
          end

          it "does not create a new survey_brief_job" do
            expect(SurveyBriefJob.count).to eq 0
          end

          it "does not queue a SurveyBriefWorker job" do
            expect(SurveyBriefWorker).not_to have_enqueued_sidekiq_job
          end
        end
      end
    end
  end
end
