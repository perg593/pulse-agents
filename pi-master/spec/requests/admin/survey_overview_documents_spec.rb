# frozen_string_literal: true
require 'spec_helper'

describe "Admin::SurveyOverviewDocuments" do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:other_survey) { create(:survey, account: other_account) }
  let(:user) { create(:user, account: account, admin: true) }
  let(:other_user) { create(:user, account: other_account, admin: true) }
  let(:screenshot_file) do
    instance_double(
      ActionDispatch::Http::UploadedFile,
      original_filename: 'test_image.png',
      content_type: 'image/png',
      read: 'fake image data'
    )
  end
  let(:valid_configuration) do
    {
      target_url: 'https://example.com',
      cookie_selectors: ['.cookie-banner', '#cookie-notice'],
      viewport_config: {
        'desktop_width' => 1920,
        'desktop_height' => 1080,
        'mobile_width' => 375,
        'mobile_height' => 667
      }
    }
  end

  before do
    # Stub the file upload
    # rubocop:disable Rspec/AnyInstance - Easier than using fixtures
    allow_any_instance_of(SurveyOverviewScreenshotUploader).to receive(:store!).and_return(true)
    allow_any_instance_of(SurveyOverviewScreenshotUploader).to receive(:url).and_return('https://example.com/test_image.png')
    allow_any_instance_of(SurveyOverviewScreenshotUploader).to receive(:present?).and_return(true)
  end

  describe "POST /admin/survey_overview_documents" do
    context "when not signed in" do
      it "returns 302" do
        post admin_survey_overview_documents_path, params: {
          survey_overview_document: {
            survey_id: survey.id,
            survey_editor_screenshot: screenshot_file,
            client_site_configuration: valid_configuration
          }
        }

        assert_response 302
      end
    end

    context "when the record is invalid" do
      before do
        sign_in user

        # Create an unfinished survey overview document to trigger validation
        create(:survey_overview_document, survey: survey, status: :pending)

        post admin_survey_overview_documents_path, params: {
          survey_overview_document: {
            survey_id: survey.id,
            survey_editor_screenshot: screenshot_file,
            client_site_configuration: valid_configuration
          }
        }
      end

      it "returns 422" do
        assert_response 422
      end

      it "returns error messages" do
        json_response = JSON.parse(response.body)
        expect(json_response["errors"]).to include("Status A survey overview document is already being generated. Please wait for it to complete.")
      end
    end

    context "when signed in" do
      before do
        sign_in user
      end

      context "when the record is valid" do
        before do
          post admin_survey_overview_documents_path, params: {
            survey_overview_document: {
              survey_id: survey.id,
              survey_editor_screenshot: screenshot_file,
              client_site_configuration: valid_configuration
            }
          }
        end

        context "when not a member of the account" do
          let(:user) { create(:user, admin: true) }

          it "returns 403" do
            assert_response 403
          end
        end

        context "when not an admin" do
          let(:user) { create(:user, account: account, admin: false) }

          it "returns 302" do
            assert_response 302
          end
        end

        context "when an admin member of the account and signed in" do
          it "returns 201" do
            assert_response :created
          end

          it "creates a new survey overview document" do
            expect(SurveyOverviewDocument.count).to eq 1

            survey_overview_document = SurveyOverviewDocument.first
            json_response = JSON.parse(response.body)

            expect(json_response["id"]).to eq survey_overview_document.id
            expect(json_response["status"]).to eq "capturing_remote_screenshots"

            expect(survey_overview_document.survey_id).to eq survey.id
            expect(survey_overview_document.status).to eq "capturing_remote_screenshots"
            expect(survey_overview_document.survey_editor_screenshot).to be_present
            expect(survey_overview_document.client_site_configuration).to eq valid_configuration.stringify_keys
          end

          it "requires survey_id parameter" do
            post admin_survey_overview_documents_path, params: {
              survey_overview_document: {
                survey_editor_screenshot: screenshot_file,
                client_site_configuration: valid_configuration
              }
            }

            assert_response 403
            json_response = JSON.parse(response.body)
            expect(json_response).to eq({ "error"=>"You do not have permission to access this survey. Please contact support for assistance." })
          end

          it "starts processing the survey overview document" do
            survey_overview_document = SurveyOverviewDocument.first

            expect(survey_overview_document.status).to eq "capturing_remote_screenshots"
          end
        end
      end

      context "with invalid client site configuration" do
        let(:invalid_configuration) do
          {
            target_url: 'not-a-url',
            cookie_selectors: 'not-an-array'
          }
        end

        before do
          post admin_survey_overview_documents_path, params: {
            survey_overview_document: {
              survey_id: survey.id,
              survey_editor_screenshot: screenshot_file,
              client_site_configuration: invalid_configuration
            }
          }
        end

        it "returns 422" do
          assert_response 422
        end

        it "returns validation errors" do
          json_response = JSON.parse(response.body)

          expect(json_response["errors"]).to include("Client site configuration target_url must be a valid URL")
        end
      end

      context "with invalid viewport configuration" do
        let(:invalid_viewport_configuration) do
          {
            target_url: 'https://example.com',
            cookie_selectors: [],
            viewport_config: {
              'desktop_width' => 'invalid',
              'desktop_height' => -100,
              'mobile_width' => 50, # Too small
              'mobile_height' => 5000 # Too large
            }
          }
        end

        before do
          post admin_survey_overview_documents_path, params: {
            survey_overview_document: {
              survey_id: survey.id,
              survey_editor_screenshot: screenshot_file,
              client_site_configuration: invalid_viewport_configuration
            }
          }
        end

        it "returns 422" do
          assert_response 422
        end

        it "returns validation errors" do
          json_response = JSON.parse(response.body)

          expect(json_response["errors"]).to include("Client site configuration viewport_config.desktop_width must be a positive integer")
          expect(json_response["errors"]).to include("Client site configuration viewport_config.desktop_height must be a positive integer")
          expect(json_response["errors"]).to include("Client site configuration viewport_config.mobile_width must be between 320 and 3840 pixels")
          expect(json_response["errors"]).to include("Client site configuration viewport_config.mobile_height must be between 240 and 2160 pixels")
        end
      end
    end
  end

  describe "GET /admin/survey_overview_documents/:id" do
    let(:survey_overview_document) { create(:survey_overview_document, survey: survey) }

    context "when not signed in" do
      it "returns 302" do
        get admin_survey_overview_document_path(survey_overview_document)

        assert_response 302
      end
    end

    context "when signed in as user from different account" do
      before do
        sign_in other_user
      end

      it "returns 403" do
        get admin_survey_overview_document_path(survey_overview_document)

        assert_response 403

        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("You do not have permission to access this survey. Please contact support for assistance.")
      end
    end

    context "when signed in as admin from correct account" do
      before do
        sign_in user
      end

      it "returns 200 with document details" do
        get admin_survey_overview_document_path(survey_overview_document)

        assert_response :success

        json_response = JSON.parse(response.body)
        expect(json_response["status"]).to eq(survey_overview_document.status)
      end

      context "when document has failed" do
        let(:survey_overview_document) { create(:survey_overview_document, :failed, survey: survey) }

        it "returns 200 with failure reason" do
          get admin_survey_overview_document_path(survey_overview_document)

          assert_response :success

          json_response = JSON.parse(response.body)
          expect(json_response["status"]).to eq("failed")
          expect(json_response["failure_reason"]).to eq("Test failure reason")
        end
      end
    end
  end

  describe "PATCH /admin/survey_overview_documents/:id" do
    let(:survey_overview_document) { create(:survey_overview_document, survey: survey) }
    let(:updated_configuration) do
      {
        target_url: 'https://updated-example.com',
        cookie_selectors: ['.updated-cookie-banner', '#updated-cookie-notice'],
        viewport_config: {
          'desktop_width' => 2560,
          'desktop_height' => 1440,
          'mobile_width' => 414,
          'mobile_height' => 896
        }
      }
    end

    context "when not signed in" do
      before do
        patch admin_survey_overview_document_path(survey_overview_document),
              params: {
                survey_overview_document: { client_site_configuration: updated_configuration }
              }
      end

      it "returns 302" do
        assert_response 302
      end
    end

    context "when signed in as user from different account" do
      before do
        sign_in other_user

        patch admin_survey_overview_document_path(survey_overview_document), params: {
          survey_overview_document: { client_site_configuration: updated_configuration }
        }
      end

      it "returns 403 and an error message" do
        assert_response 403

        json_response = JSON.parse(response.body)

        expect(json_response["error"]).to eq("You do not have permission to access this survey. Please contact support for assistance.")
      end
    end

    context "when signed in as admin from correct account" do
      before do
        sign_in user

        patch admin_survey_overview_document_path(survey_overview_document), params: {
          survey_overview_document: { client_site_configuration: updated_configuration }
        }
      end

      it "returns 200 with updated document" do
        assert_response :success

        json_response = JSON.parse(response.body)

        expect(json_response["id"]).to eq(survey_overview_document.id)
        expect(survey_overview_document.reload.client_site_configuration).to eq(updated_configuration.stringify_keys)
      end
    end
  end

  describe "GET /admin/survey_overview_documents/:id/presentation_url" do
    let(:survey_overview_document) { create(:survey_overview_document, survey: survey) }

    context "when not signed in" do
      before do
        get presentation_url_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 302" do
        assert_response 302
      end
    end

    context "when signed in as user from different account" do
      before do
        sign_in other_user

        get presentation_url_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 403" do
        assert_response 403

        json_response = JSON.parse(response.body)

        expect(json_response["error"]).to eq("You do not have permission to access this survey. Please contact support for assistance.")
      end
    end

    context "when signed in as admin from correct account" do
      before do
        sign_in user

        allow_any_instance_of(SurveyOverviewDocument).to receive(:google_presentation_url).and_return("https://example.com/presentation")
        get presentation_url_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 200 with presentation url" do
        assert_response :success

        json_response = JSON.parse(response.body)
        expect(json_response["url"]).to eq("https://example.com/presentation")
      end
    end
  end

  describe "POST /admin/survey_overview_documents/:id/capture_screenshots" do
    let(:survey_overview_document) { create(:survey_overview_document, survey: survey) }

    context "when not signed in" do
      before do
        post capture_screenshots_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 302" do
        assert_response 302
      end
    end

    context "when signed in as user from different account" do
      before do
        sign_in other_user

        post capture_screenshots_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 403" do
        assert_response 403

        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("You do not have permission to access this survey. Please contact support for assistance.")
      end
    end

    context "when signed in as admin from correct account" do
      before do
        sign_in user

        # rubocop:disable RSpec/ExpectInHook
        expect(SurveyOverviewDocuments::CaptureScreenshotsWorker).to receive(:perform_async).with(survey_overview_document.id)
        post capture_screenshots_admin_survey_overview_document_path(survey_overview_document)
      end

      it "returns 200 and enqueues the worker" do
        assert_response :success

        json_response = JSON.parse(response.body)
        expect(json_response["status"]).to eq(survey_overview_document.status)
      end
    end
  end
end
