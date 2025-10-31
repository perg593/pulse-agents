# frozen_string_literal: true

require 'spec_helper'
require_relative "../../../rack/pdf_templates/s3"

describe Rack::PdfTemplates::S3 do
  describe "#get_template_file_contents" do
    let(:object_key) { "A-good_and_valid_object_key.html.erb" }
    let(:file_contents) { "<html>Hello, world!</html>" }

    before do
      @dummy_file = Tempfile.new("dummy_file")
      @dummy_file.write(file_contents)
      @dummy_file.rewind

      @s3_request = stub_request(:get, "https://pi-pdf-templates.s3.us-west-2.amazonaws.com/#{object_key}").
                    to_return(status: 200, body: file_contents, headers: {})
    end

    after do
      @dummy_file.close
      @dummy_file.unlink
    end

    it "returns the file" do
      file = described_class.get_template_file_contents(object_key)

      expect(@s3_request).to have_been_requested.once

      expect(file).to eq file_contents
    end
  end
end
