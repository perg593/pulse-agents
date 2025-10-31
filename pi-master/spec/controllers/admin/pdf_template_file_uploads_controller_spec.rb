# frozen_string_literal: true
require 'spec_helper'

describe Admin::PDFTemplateFileUploadsController do
  let(:user) { create(:admin) }
  let(:survey) { create(:survey, account: user.account) }
  let(:survey_metadatum) { create(:survey_metadatum, survey: survey) }

  before do
    sign_in user
  end

  describe "#destroy" do
    before do
      stub_request(:delete, /https:\/\/pi-pdf-templates.s3.us-west-2.amazonaws.com/)
    end

    it "destroy the file on S3" do
      pdf_template_file_upload = create(:pdf_template_html_file, survey_metadatum: survey_metadatum)

      @s3_request = stub_request(:delete, "https://pi-pdf-templates.s3.us-west-2.amazonaws.com/#{pdf_template_file_upload.object_key}")

      delete :destroy, params: { id: pdf_template_file_upload.id }

      expect(@s3_request).to have_been_requested
    end

    it "destroys the file" do
      pdf_template_file_upload = create(:pdf_template_html_file, survey_metadatum: survey_metadatum)

      expect do
        delete :destroy, params: { id: pdf_template_file_upload.id }
      end.to change(PDFTemplateFileUploads::PDFTemplateHTMLFile, :count).by(-1)
    end

    context "when the file has a position" do
      before do
        @pdf_template_file_upload1 = create(:pdf_template_static_pdf, survey_metadatum: survey_metadatum)
        @pdf_template_file_upload2 = create(:pdf_template_static_pdf, survey_metadatum: survey_metadatum)
        @pdf_template_file_upload3 = create(:pdf_template_static_pdf, survey_metadatum: survey_metadatum)

        delete :destroy, params: { id: @pdf_template_file_upload2.id }
      end

      it "repositions the remaining file uploads" do
        expect(@pdf_template_file_upload1.reload.position).to eq(1)
        expect(@pdf_template_file_upload3.reload.position).to eq(2)
      end

      it "returns the remaining file uploads" do
        remaining_ids = [@pdf_template_file_upload1.id, @pdf_template_file_upload3.id]

        expect(JSON.parse(response.body)["files"].map { |file| file["id"] }).to match_array(remaining_ids)
      end
    end
  end
end
