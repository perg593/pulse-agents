# frozen_string_literal: true
require 'spec_helper'

require_relative "schemas/pdf_presenter"

describe Admin::PDFTemplatePresenter do
  let(:survey) { create(:survey) }

  describe "#props" do
    let(:presenter) { described_class.new(survey) }

    before do
      stub_request(:put, /https:\/\/pi-pdf-templates.s3.us-west-2.amazonaws.com/)

      @survey_metadatum = create(:survey_metadatum, survey: survey)

      @pdf_template_html_file = create(:pdf_template_html_file_with_file, survey_metadatum: survey.metadatum)
    end

    # TODO: Find a foolproof way to destroy all TempFiles
    after do
      stub_request(:delete, /https:\/\/pi-pdf-templates.s3.us-west-2.amazonaws.com/)

      @pdf_template_html_file.destroy
    end

    it "returns a valid schema" do
      assert_valid_schema Schemas::PDFPresenter::PropsSchema, presenter.props
    end

    it "returns valid survey props" do
      props = presenter.props

      expect(props[:survey][:name]).to eq survey.name
      expect(props[:survey][:id]).to eq survey.id
    end

    it "returns a valid template_file" do
      props = presenter.props

      file = props[:templateFile]

      expect(file[:id]).to eq @pdf_template_html_file.id
      expect(file[:name]).to eq @pdf_template_html_file.file_name
    end

    describe "asset files" do
      context "when there are asset files" do
        before do
          @pdf_template_asset = create(:pdf_template_asset, survey_metadatum: @survey_metadatum, tempfile: Tempfile.new("test.css"))
        end

        # TODO: Find a foolproof way to destroy all TempFiles
        after do
          stub_request(:delete, /https:\/\/pi-pdf-templates.s3.us-west-2.amazonaws.com/)

          @pdf_template_asset.destroy
        end

        it "returns valid asset_files" do
          props = presenter.props

          asset_files = props[:assetFiles]

          expect(asset_files.length).to eq 1

          asset_file = asset_files[0]
          expect(asset_file[:id]).to eq @pdf_template_asset.id
          expect(asset_file[:name]).to eq @pdf_template_asset.file_name
        end
      end

      context "when there are no asset files" do
        it "returns an empty array" do
          props = presenter.props

          asset_files = props[:assetFiles]

          expect(asset_files).to be_empty
        end
      end
    end

    describe "static pdf files" do
      context "when there are static pdf files" do
        before do
          @pdf_template_static_pdfs = [
            create(:pdf_template_static_pdf, survey_metadatum: @survey_metadatum, tempfile: Tempfile.new("test_1.pdf")),
            create(:pdf_template_static_pdf, survey_metadatum: @survey_metadatum, tempfile: Tempfile.new("test_2.pdf"))
          ]

          @pdf_template_static_pdfs[0].position = 2
          @pdf_template_static_pdfs[0].save

          @pdf_template_static_pdfs[1].position = 1
          @pdf_template_static_pdfs[1].save
        end

        # TODO: Find a foolproof way to destroy all TempFiles
        after do
          stub_request(:delete, /https:\/\/pi-pdf-templates.s3.us-west-2.amazonaws.com/)

          @pdf_template_static_pdfs.each(&:destroy)
        end

        it "returns valid static_pdf_files" do
          props = presenter.props

          static_pdf_files = props[:staticPdfFiles]

          expect(static_pdf_files.length).to eq 2

          @pdf_template_static_pdfs.sort_by { |pdf| pdf.metadata["position"] }.each_with_index do |pdf_template_static_pdf, i|
            expect(static_pdf_files[i][:id]).to eq pdf_template_static_pdf.id
            expect(static_pdf_files[i][:name]).to eq pdf_template_static_pdf.file_name
            expect(static_pdf_files[i][:position]).to eq pdf_template_static_pdf.position
          end
        end
      end

      context "when there are no static pdf files" do
        it "returns an empty array" do
          props = presenter.props

          static_pdf_files = props[:staticPdfFiles]

          expect(static_pdf_files).to be_empty
        end
      end
    end
  end
end
