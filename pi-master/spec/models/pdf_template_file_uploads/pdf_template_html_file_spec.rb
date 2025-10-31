# frozen_string_literal: true
require 'spec_helper'

describe PDFTemplateFileUploads::PDFTemplateHTMLFile do
  describe "validations" do
    describe "object_key" do
      it_behaves_like "s3 object key validation" do
        subject { create(:pdf_template_html_file) }

        let(:attribute_to_validate) { :object_key }
      end
    end
  end
end
