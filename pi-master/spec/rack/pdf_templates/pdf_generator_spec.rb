# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../rack/pdf_templates/pdf_generator'
require_relative '../../../rack/pdf_templates/s3'

describe Rack::PdfTemplates::PDFGenerator do
  describe "#generate" do
    before do
      object_key = "#{FFaker::Lorem.word}/#{FFaker::Lorem.word}.html.erb"

      @survey = create(:survey)
      create(:survey_metadatum, survey: @survey)
      create(:pdf_template_html_file, survey_metadatum: @survey.metadatum, object_key: object_key)

      @template = Tempfile.new(["test", ".html.erb"])
      template_contents = "<html>Hello, world!</html>"
      @template.write(template_contents)
      @template.rewind

      # Not going to actually upload to and download from S3 for a test
      allow(Rack::PdfTemplates::S3).to receive(:get_template_file_contents).with(object_key).and_return(@template)

      @final_pdf = "%PDF"

      # Basically have to mock everything provided by WickedPdf and CombinePDF
      # since we don't want either running in tests
      # (why not? Because it was a hassle installing those libraries' dependencies.)
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(WickedPdf).to receive(:pdf_from_string).and_return(@final_pdf)
    end

    after do
      @template&.close
      @template&.unlink
    end

    it "returns a PDF" do
      pdf = described_class.new.generate(@survey.id, {questions: []})

      # https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.4.pdf
      # The first line of a PDF file is a header identifying the version of the
      # PDF specifica-tion to which the file conforms. For a file conforming to PDF version 1.4,
      # the header should be %PDF−1.4
      expect(pdf).to eq(@final_pdf)
    end
  end
end
