# frozen_string_literal: true
require 'spec_helper'

describe Control::AISummarizationJobsController do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:survey) { create(:survey, account: account) }
  let(:question) { create(:free_text_question, survey: survey) }
  let(:question_id) { question.id }

  before do
    sign_in user
  end

  describe "#POST /ai_summarization_jobs" do
    context "when feature is enabled for the account" do
      let(:account) { create(:account, ai_summaries_enabled: true) }

      before do
        post :create, params: { ai_summarization_job: { question_id: question_id } }
      end

      context "when the user belongs to the account" do
        it "returns 200" do
          assert_response :ok
        end

        context "when the question exists" do
          it "returns 200" do
            assert_response :ok
          end

          it "returns the ID of the record that was created" do
            expected_response_object = {"id" => AISummarizationJob.last.id}

            expect(JSON.parse(response.body)).to eq expected_response_object
          end

          it "creates an AISummarizationJob" do
            expect(AISummarizationJob.count).to eq 1
          end
        end

        context "when the question does not exist" do
          let(:question_id) { -1 }

          it "returns 404" do
            assert_response :not_found
          end

          it "returns an error message" do
            expected_response_object = {"error" => "Unauthorized"}

            expect(JSON.parse(response.body)).to eq expected_response_object
          end

          it "does not create an AISummarizationJob" do
            expect(AISummarizationJob.count).to eq 0
          end
        end
      end

      context "when the user does not belong to the account that owns the question" do
        let(:user) { create(:user, account: create(:account, ai_summaries_enabled: true)) }

        it "returns 404" do
          assert_response :not_found
        end

        it "returns an error message" do
          expected_response_object = {"error" => "Unauthorized"}

          expect(JSON.parse(response.body)).to eq expected_response_object
        end

        it "does not create an AISummarizationJob" do
          expect(AISummarizationJob.count).to eq 0
        end
      end
    end

    context "when feature is disabled for the account" do
      let(:account) { create(:account, ai_summaries_enabled: false) }

      before do
        post :create, params: { ai_summarization_job: { question_id: question_id } }
      end

      it "returns 403" do
        assert_response :forbidden
      end

      it "returns an error message" do
        expected_response_object = {"error" => "Feature disabled for this account."}

        expect(JSON.parse(response.body)).to eq expected_response_object
      end

      it "does not create an AISummarizationJob" do
        expect(AISummarizationJob.count).to eq 0
      end
    end
  end

  describe "#GET /ai_summarization_job/:id" do
    let(:ai_summarization_job) { create(:ai_summarization_job, question: question) }
    let(:ai_summarization_job_id) { ai_summarization_job.id }

    before do
      get :show, params: { id: ai_summarization_job_id }
    end

    # User -> Account -> Survey -> Question -> AISummarizationJob
    context "when the user is associated the job" do
      it "returns 200" do
        assert_response :ok
      end

      it "returns the expected response object" do
        response_object = JSON.parse(response.body)

        expect(response_object["datetime"]).to eq ai_summarization_job.created_at.strftime("%m/%d/%Y %H:%M")
        expect(response_object["summary"]).to eq ai_summarization_job.summary
        expect(response_object["status"]).to eq ai_summarization_job.status
      end

      context "when the job record does not exist" do
        it "handles missing records" do
          it_handles_missing_records({ verb: :get, url: :show, json: :always })
        end
      end
    end

    context "when the user is not associated (via the question) with the job" do
      let(:user) { create(:user) }

      it "returns 403" do
        assert_response :forbidden
      end

      it "returns an error message" do
        expected_response_object = {"error" => "Unauthorized. Wrong account."}

        expect(JSON.parse(response.body)).to eq expected_response_object
      end
    end
  end
end
