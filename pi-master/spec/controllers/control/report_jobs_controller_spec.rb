# frozen_string_literal: true
require 'spec_helper'
include Control::FiltersHelper

describe Control::ReportJobsController do
  describe "GET #status" do
    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }
    let(:user) { create(:user, account: account) }
    let(:current_user_email) { user.email }

    describe "succeeds" do
      def returns_report_status(json_response, report_job)
        expect(json_response.keys).to match_array %w(status url)

        expect(json_response["status"]).to eq report_job.status.to_s
        expect(json_response["url"]).to eq report_job.report_url
      end

      context "when the user is an admin" do
        before do
          session[:sudo_from_id] = 42
        end

        it "returns report job status information" do
          report_job = create(:report_job, user: user, survey: survey, current_user_email: current_user_email, sudo_from_id: 42)

          sign_in user

          get :status, params: { id: report_job.id }

          assert_response 200

          returns_report_status(json_response, report_job)
        end
      end

      context "when the user is not an admin" do
        it "returns report job status information" do
          report_job = create(:report_job, user: user, survey: survey, current_user_email: current_user_email)

          sign_in user

          get :status, params: { id: report_job.id }

          assert_response 200

          returns_report_status(json_response, report_job)
        end
      end
    end

    describe "fails" do
      context "when the user is not signed in" do
        let(:report_job) { create(:report_job, user: user, survey: survey, current_user_email: current_user_email) }

        it "returns 302" do
          get :status, params: { id: report_job.id }

          assert_response 302
          assert_redirected_to sign_in_url
        end
      end

      # report has sudo_id <-- user does not have sudo id
      # report has no sudo_id has user_id <-- user does not match user_id
      context "when the user is not the owner of the report job" do
        context "when the report job has a sudo_user_id" do
          let(:report_job) { create(:report_job, user: user, survey: survey, current_user_email: current_user_email, sudo_from_id: 42) }

          it "returns 403 for the wrong admin" do
            session[:sudo_from_id] = 1

            sign_in user

            get :status, params: { id: report_job.id }

            assert_response 403
          end
        end

        context "when the report job has no sudo_user_id" do
          let(:report_job) { create(:report_job, user: user, survey: survey, current_user_email: current_user_email) }

          it "returns 403" do
            user = create(:user)

            sign_in user

            get :status, params: { id: report_job.id }

            assert_response 403
          end
        end
      end
    end
  end

  describe "POST #create" do
    before do
      ReportJob.delete_all
      Sidekiq::Worker.clear_all
      Sidekiq::Queue.new.clear
    end

    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }
    let(:user) { create(:user, account: account) }
    let(:survey_locale_group) { nil }

    describe "fails" do
      context "when the user is not signed in" do
        it "returns 302" do
          post :create, params: { survey_id: survey.id }

          expect_nothing_queued

          assert_response 302
        end
      end

      context "when the survey does not belong to the current account" do
        let(:survey) { create(:survey, account: create(:account)) }

        it "returns 403" do
          sign_in user

          post :create, params: { survey_id: survey.id }

          expect_nothing_queued

          assert_response 403
        end
      end

      context "when the survey_locale_group does not belong to the current account" do
        let(:survey_locale_group) { create(:survey_locale_group, account: create(:account)) }

        it "returns 403" do
          sign_in user

          post :create, params: { survey_locale_group_id: survey_locale_group.id }

          expect_nothing_queued

          assert_response 403
        end
      end

      context "when neither a survey_id nor a survey_locale_group_id is provided" do
        it "returns 404" do
          sign_in user

          post :create

          expect_nothing_queued

          assert_response 404
        end
      end

      context "when both a survey_id and a survey_locale_group_id are provided" do
        let(:survey_locale_group) { create(:survey_locale_group, account: account) }

        it "returns 404" do
          sign_in user

          post :create, params: { survey_id: survey.id, survey_locale_group_id: survey_locale_group.id }

          expect_nothing_queued

          assert_response 404
        end
      end

      context "when the user already has an identical report in progress" do
        before do
          session[:sudo_from_id] = 42

          existing_report_job = ReportJob.create(current_user_email: user.email, survey_id: survey.id, user_id: user.id, sudo_from_id: session[:sudo_from_id])

          sign_in user
        end

        it "returns 409" do
          post :create, params: { survey_id: survey.id }

          assert_response 409

          expect(ReportJob.count).to eq 1
          expect(ReportWorker).not_to have_enqueued_sidekiq_job
        end
      end

      # rubocop:disable RSpec/AnyInstance
      # This is simpler than specifying filter parameters (which may change)
      context "when the report would cross the impression threshold" do
        before do
          sign_in user

          stub_const("Control::ReportJobsController::IMPRESSION_THRESHOLD", 1)
        end

        context "when the survey has many impressions" do
          before do
            create(:survey_submission_cache, survey: survey, impression_count: 2)
          end

          context "when a filter is specified" do
            before do
              ReportJob.any_instance.stub(:filters?).and_return(true)
            end

            it "queues the report" do
              post :create, params: { survey_id: survey.id }

              expect_report_queued
            end
          end

          context "when no filters are specified" do
            it "returns 404" do
              post :create, params: { survey_id: survey.id }

              assert_response 404

              expect_nothing_queued
            end
          end
        end

        context "when the survey locale group has many impressions" do
          let(:survey_locale_group) { create(:survey_locale_group, account: account) }
          let(:survey) { nil }

          before do
            survey_locale_group.surveys << create(:survey, account: survey_locale_group.account)
            create(:survey_submission_cache, survey: survey_locale_group.surveys.first, impression_count: 2)
          end

          context "when a filter is specified" do
            before do
              ReportJob.any_instance.stub(:filters?).and_return(true)
            end

            it "queues the report" do
              post :create, params: { survey_locale_group_id: survey_locale_group.id }

              expect_report_queued
            end
          end

          context "when no filters are specified" do
            it "returns 404" do
              post :create, params: { survey_locale_group_id: survey_locale_group.id }

              assert_response 404

              expect_nothing_queued
            end
          end
        end
      end

      def expect_nothing_queued
        expect(ReportJob.count).to eq 0
        expect(ReportWorker).not_to have_enqueued_sidekiq_job
      end
    end

    context "when the survey belongs to the current account" do
      context "when a reporting-only user is signed in" do
        let(:user) { create(:reporting_only_user, account: account) }

        before do
          sign_in user
        end

        it "creates a ReportJob based off of the survey and queues a ReportWorker job" do
          post :create, params: { survey_id: survey.id }

          expect_report_queued
        end
      end

      context "when a full-access user is signed in" do
        before do
          sign_in user
        end

        it "creates a ReportJob based off of the survey and queues a ReportWorker job" do
          post :create, params: { survey_id: survey.id }

          expect_report_queued
        end
      end

      context "when filters are provided" do
        before do
          sign_in user
        end

        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            post :create, params: { survey_id: survey.id, **filters }

            report_job = ReportJob.first

            filters.each do |filter_key, filter_value|
              case filter_key
              when :date_range
                # expect an EST/EDT value
                parsed_date_range = parse_filters(filters)[filter_key]

                expect(report_job.date_range).to eq parsed_date_range
              when :device_types
                expect(report_job.device_filter).to eq filter_value
              when :market_ids
                expect(report_job.market_ids).to eq filter_value
              when :completion_urls
                completion_urls_json = filter_value.map do |completion_url_string|
                  JSON.parse(completion_url_string)
                end

                expect(report_job.filters["completion_urls"]).to eq completion_urls_json
              when :pageview_count, :visit_count
                filter_json = JSON.parse(filter_value)

                expect(report_job.filters[filter_key.to_s]).to eq filter_json
              end
            end

            report_job_has_correct_properties(report_job)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            # noop
          end
        end
      end

      context "when an admin has logged in as a user of this account" do
        before do
          # faking admin login
          @admin = create(:admin)
          session[:sudo_from_id] = @admin.id

          sign_in user
        end

        it "includes the sudo_from_id from session" do
          post :create, params: { survey_id: survey.id }

          expect_report_queued
          report_job = ReportJob.first
          expect(report_job.sudo_from_id).to eq @admin.id
        end
      end
    end

    context "when the survey locale group belongs to the current account" do
      let(:survey_locale_group) { create(:survey_locale_group, account: account) }
      let(:survey) { nil }

      context "when a reporting-only user is signed in" do
        let(:user) { create(:reporting_only_user, account: account) }

        before do
          sign_in user
        end

        it "creates a ReportJob based off of the survey locale group and queues a ReportWorker job" do
          post :create, params: { survey_locale_group_id: survey_locale_group.id }

          expect_report_queued
        end
      end

      context "when a full-access user is signed in" do
        before do
          sign_in user
        end

        it "creates a ReportJob based off of the survey locale group and queues a ReportWorker job" do
          post :create, params: { survey_locale_group_id: survey_locale_group.id }

          expect_report_queued
        end
      end

      context "when an admin has logged in as a user of this account" do
        before do
          # faking admin login
          @admin = create(:admin)
          session[:sudo_from_id] = @admin.id

          sign_in user
        end

        it "includes the sudo_from_id from session" do
          post :create, params: { survey_locale_group_id: survey_locale_group.id }

          expect_report_queued

          report_job = ReportJob.first
          expect(report_job.sudo_from_id).to eq @admin.id
        end
      end
    end

    def expect_report_queued
      assert_response 200

      expect(ReportJob.count).to eq 1

      report_job = ReportJob.first

      presenter = ReportJobPresenter.new(user)
      job = presenter.export_job(report_job)

      expect(json_response["reportJob"]).to eq(job)
      expect(ReportWorker).to have_enqueued_sidekiq_job(report_job.id)

      report_job_has_correct_properties(report_job)
    end

    def report_job_has_correct_properties(report_job)
      expect(report_job.current_user_email).to eq(user.email)
      expect(report_job.report_url).to be_nil
      expect(report_job.created?).to be true
      expect(report_job.sudo_from_id).to eq(session[:sudo_from_id])
      expect(report_job.survey_id).to eq(survey&.id)
      expect(report_job.survey_locale_group_id).to eq(survey_locale_group&.id)
      expect(report_job.user_id).to eq(user.id)
    end
  end
end
