# frozen_string_literal: true
require 'spec_helper'

describe SurveyOverviewDocument do
  it "is able to create a survey overview document" do
    create(:survey_overview_document)

    expect(described_class.count).to eq(1)
  end

  describe "validations" do
    it "requires a survey" do
      survey_overview_document = build(:survey_overview_document, survey: nil)

      expect(survey_overview_document).to validate_presence_of(:survey)
    end

    it "has a default status of pending" do
      survey_overview_document = build(:survey_overview_document)

      expect(survey_overview_document.status).to eq("pending")
    end
  end

  describe "unfinished jobs validation" do
    let(:survey) { create(:survey) }

    context "when there is an unfinished job for the same survey" do
      before do
        create(:survey_overview_document, survey: survey, status: :pending)
      end

      it "prevents creating another document" do
        new_document = build(:survey_overview_document, survey: survey)

        expect(new_document).not_to be_valid
        expect(new_document.errors[:status]).to include("A survey overview document is already being generated. Please wait for it to complete.")
      end
    end

    context "when there are documents for different surveys" do
      let(:other_survey) { create(:survey) }

      before do
        create(:survey_overview_document, survey: survey, status: :pending)
      end

      it "allows creating a document for a different survey" do
        new_document = build(:survey_overview_document, survey: other_survey)

        expect(new_document).to be_valid
      end
    end

    context "when previous document is completed" do
      before do
        create(:survey_overview_document, survey: survey, status: :completed)
      end

      it "allows creating a new document" do
        new_document = build(:survey_overview_document, survey: survey)

        expect(new_document).to be_valid
      end
    end

    context "when previous document failed" do
      before do
        create(:survey_overview_document, survey: survey, status: :failed)
      end

      it "allows creating a new document" do
        new_document = build(:survey_overview_document, survey: survey)

        expect(new_document).to be_valid
      end
    end
  end

  describe "status transitions" do
    let(:survey_overview_document) { create(:survey_overview_document) }

    describe "#fail!" do
      let(:reason) { "Failed to capture screenshot" }

      it "changes status to failed and sets failure reason" do
        survey_overview_document.fail!(reason)

        expect(survey_overview_document.status).to eq("failed")
        expect(survey_overview_document.failure_reason).to eq(reason)
      end
    end
  end

  describe ".unfinished" do
    before do
      create(:survey_overview_document, survey: create(:survey), status: :pending)
      create(:survey_overview_document, survey: create(:survey), status: :capturing_remote_screenshots)
      create(:survey_overview_document, survey: create(:survey), status: :generating_slides)
      create(:survey_overview_document, survey: create(:survey), status: :completed)
      create(:survey_overview_document, survey: create(:survey), status: :failed)
    end

    it "returns only unfinished documents" do
      expect(described_class.unfinished.count).to eq(3)
    end
  end

  describe "authentication configuration" do
    let(:survey_overview_document) { build(:survey_overview_document) }

    it "allows setting and getting authentication configuration" do
      auth_config = {
        'type' => 'basic',
        'username' => 'testuser',
        'password' => 'testpass'
      }

      survey_overview_document.authentication_config = auth_config

      expect(survey_overview_document.authentication_config).to eq(auth_config)
    end

    it "allows form authentication configuration with selectors" do
      auth_config = {
        'type' => 'form',
        'username' => 'testuser',
        'password' => 'testpass',
        'form_selectors' => {
          'username_selector' => '#username',
          'password_selector' => '#password',
          'submit_selector' => 'button[type="submit"]'
        }
      }

      survey_overview_document.authentication_config = auth_config

      expect(survey_overview_document.authentication_config).to eq(auth_config)
    end
  end
end
