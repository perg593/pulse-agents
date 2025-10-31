# frozen_string_literal: true

require 'spec_helper'
require_relative "../../../../rack/database/pdf_templates/database"
require_relative "../../../../spec/rack/schemas/template_submission_schema"

describe Rack::Database::PDFTemplates::Database do
  let(:mixin_dummy_class) do
    Class.new do
      include Rack::Postgres
      include Rack::Database::PDFTemplates::Database
    end
  end

  let(:dummy_object) do
    mixin_dummy_class.new
  end

  let(:survey) { create(:survey) }

  describe "#get_survey_pdf_template_object_keys" do
    context "when the survey has one file" do
      before do
        survey_metadatum = create(:survey_metadatum, survey: survey)

        @object_key = FFaker::Lorem.unique.word

        create(:pdf_template_html_file, survey_metadatum: survey_metadatum, object_key: @object_key)
      end

      it "returns an array with that file's object_key" do
        object_key = dummy_object.get_survey_pdf_template_object_keys(survey.id)

        expect(object_key).to eq([@object_key])
      end
    end

    context "when the survey has more than one file" do
      before do
        survey_metadatum = create(:survey_metadatum, survey: survey)

        @template_object_key = FFaker::Lorem.unique.word
        @asset_object_key = FFaker::Lorem.unique.word
        @static_pdf_object_key = FFaker::Lorem.unique.word

        create(:pdf_template_html_file, survey_metadatum: survey_metadatum, object_key: @template_object_key)
        create(:pdf_template_asset, survey_metadatum: survey_metadatum, object_key: @asset_object_key)
        create(:pdf_template_static_pdf, survey_metadatum: survey_metadatum, object_key: @static_pdf_object_key)
      end

      it "returns an array of object_keys" do
        object_keys = dummy_object.get_survey_pdf_template_object_keys(survey.id)

        expect(object_keys).to contain_exactly(@template_object_key, @asset_object_key, @static_pdf_object_key)
      end
    end

    context "when the survey has no files" do
      it "returns an empty array" do
        object_key = dummy_object.get_survey_pdf_template_object_keys(survey.id)

        expect(object_key).to eq([])
      end
    end

    context "when postgres breaks" do
      before do
        allow(dummy_object).to receive(:postgres_execute).and_return(false)
      end

      it "returns nil" do
        object_key = dummy_object.get_survey_pdf_template_object_keys(survey.id)

        expect(object_key).to be_nil
      end
    end
  end

  describe "#get_template_submission" do
    before do
      create(:survey_metadatum, survey: survey)

      survey.questions.each do |question|
        create(:question_metadatum, question: question)

        question.possible_answers.each do |possible_answer|
          create(:possible_answer_metadatum, possible_answer: possible_answer)
        end
      end
    end

    it "returns the expected schema" do
      template_submission = dummy_object.get_template_submission(survey.id.to_s)

      assert_valid_schema RackSchemas::PDFTemplates::TemplateSubmissionSchema, template_submission
    end

    it "returns the expected data" do
      template_submission = dummy_object.get_template_submission(survey.id.to_s)

      expect(template_submission).to eq(
        questions: survey.questions.map do |question|
          {
            id: question.id,
            type: question.question_type,
            content: question.content,
            metaname: question.metadatum.name,
            possible_answers: question.possible_answers.sort_by_position.map do |possible_answer|
              {
                id: possible_answer.id,
                content: possible_answer.content,
                metaname: possible_answer.metadatum.name
              }
            end
          }
        end
      )
    end
  end
end
