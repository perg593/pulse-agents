# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../rack/pdf_templates/file_fetcher'

describe Rack::PdfTemplates::FileFetcher do
  let(:file_fetcher) { described_class.new }
  let(:survey) { create(:survey) }

  before do
    @survey_metadatum = create(:survey_metadatum, survey: survey)
  end

  RSpec::Matchers.define :be_a_valid_template_file do |expected_contents, expected_path|
    match do |actual_file|
      actual_file.is_a?(File) &&
        actual_file.pos == 0 &&
        actual_file.path.end_with?(expected_path) &&
        actual_file.read == expected_contents
    end

    failure_message do |actual_file|
      messages = []

      messages << "Expected #{actual_file} to be a File, but it was a #{actual_file.class}" unless actual_file.is_a?(File)
      messages << "Expected #{actual_file} to be at position 0, but it was at position #{actual_file.pos}" unless actual_file.pos == 0
      messages << "Expected #{actual_file.path} to end with #{expected_path}, but it did not" unless actual_file.path.end_with?(expected_path)
      messages << "Expected #{actual_file.read} to match #{expected_contents}, but it did not" unless actual_file.read == expected_contents

      messages.join("\n")
    end
  end

  describe "#fetch_files" do
    after do
      file_fetcher.clean_up_files
    end

    context "when the survey has no associated files" do
      it "returns a hash of files" do
        result = file_fetcher.fetch_files(survey.id)

        expect(result.keys).to contain_exactly(:template_file, :css_files, :image_files, :font_files, :pdf_files)

        expect(result[:template_file]).to be_nil
        expect(result[:css_files]).to eq([])
        expect(result[:image_files]).to eq([])
        expect(result[:font_files]).to eq([])
        expect(result[:pdf_files]).to eq([])
      end
    end

    describe "file checks" do
      before do
        stub_request(:get, "https://pi-pdf-templates.s3.us-west-2.amazonaws.com/#{object_key}").
          with(headers: { 'Accept'=>'*/*', 'Accept-Encoding'=>'', 'Host'=>'pi-pdf-templates.s3.us-west-2.amazonaws.com' }).
          to_return(status: 200, body: file_contents, headers: {})
      end

      context "when the survey has an associated template file" do
        let(:file_contents) { "<html>Hello, world!</html>" }
        let(:object_key) { create(:pdf_template_html_file_without_file, survey_metadatum: @survey_metadatum).object_key }

        it "returns a file" do
          result = file_fetcher.fetch_files(survey.id)

          template_file = result[:template_file]

          expect(template_file).to be_a_valid_template_file(file_contents, object_key)
        end
      end

      context "when the survey has an associated css file" do
        let(:file_contents) { "body { width: 100% }" }
        let(:object_key) { create(:pdf_css_asset, survey_metadatum: @survey_metadatum).object_key }

        it "returns a file" do
          result = file_fetcher.fetch_files(survey.id)

          css_file = result[:css_files].first

          expect(css_file).to be_a_valid_template_file(file_contents, object_key)
        end
      end

      context "when the survey has an associated pdf file" do
        let(:file_contents) { "%PDF" }
        let(:position_relative_to_template) { -1 }
        let(:asset) do
          a = create(:pdf_template_static_pdf, survey_metadatum: @survey_metadatum)
          a.position = position_relative_to_template
          a.save
          a
        end
        let(:object_key) { asset.object_key }

        it "returns a file" do
          result = file_fetcher.fetch_files(survey.id)

          pdf_file = result[:pdf_files].first

          expect(pdf_file).is_a?(Hash)
          expect(pdf_file[:file]).to be_a_valid_template_file(file_contents, object_key)
          expect(pdf_file[:metadata]["position"]).to eq(position_relative_to_template)
        end
      end

      describe "font files" do
        %w(ttf otf woff woff2).each do |extension|
          context "when the survey has an associated #{extension} file" do
            let(:file_contents) { "FONT_DATA" }
            let(:asset) { create(:pdf_template_asset, survey_metadatum: @survey_metadatum, object_key: "#{SecureRandom.uuid}.#{extension}") }
            let(:object_key) { asset.object_key }

            it "returns a file" do
              result = file_fetcher.fetch_files(survey.id)

              font_file = result[:font_files].first

              expect(font_file).to be_a_valid_template_file(file_contents, object_key)
            end
          end
        end
      end

      describe "image files" do
        %w(jpg jpeg png gif svg).each do |extension|
          context "when the survey has an associated #{extension} file" do
            let(:file_contents) { "IMAGE_DATA" }
            let(:asset) { create(:pdf_template_asset, survey_metadatum: @survey_metadatum, object_key: "#{SecureRandom.uuid}.#{extension}") }
            let(:object_key) { asset.object_key }

            it "returns a file" do
              result = file_fetcher.fetch_files(survey.id)

              image_file = result[:image_files].first

              expect(image_file).to be_a_valid_template_file(file_contents, object_key)
            end
          end
        end
      end
    end
  end

  describe "#clean_up_files" do
    before do
      object_key_content_pairs = [
        [create(:pdf_template_html_file_without_file, survey_metadatum: @survey_metadatum).object_key, "<html>Hello, world!</html>"],
        [create(:pdf_template_static_pdf, survey_metadatum: @survey_metadatum).object_key, "%PDF"],
        [create(:pdf_css_asset, survey_metadatum: @survey_metadatum).object_key, "body { width: 100% }"],
        [create(:pdf_template_asset, survey_metadatum: @survey_metadatum, object_key: "#{SecureRandom.uuid}.ttf").object_key, "FONT_DATA"],
        [create(:pdf_template_asset, survey_metadatum: @survey_metadatum, object_key: "#{SecureRandom.uuid}.jpg").object_key, "IMAGE_DATA"]
      ]

      object_key_content_pairs.each do |object_key, content|
        stub_request(:get, "https://pi-pdf-templates.s3.us-west-2.amazonaws.com/#{object_key}").
          with(headers: { 'Accept'=>'*/*', 'Accept-Encoding'=>'', 'Host'=>'pi-pdf-templates.s3.us-west-2.amazonaws.com' }).
          to_return(status: 200, body: content, headers: {})
      end
    end

    it "cleans up files" do
      files = file_fetcher.fetch_files(survey.id)

      file_fetcher.clean_up_files

      expect(File.exist?(files[:template_file].path)).to be false

      files[:css_files].each do |file|
        expect(File.exist?(file.path)).to be false
      end

      files[:image_files].each do |file|
        expect(File.exist?(file.path)).to be false
      end

      files[:pdf_files].each do |file|
        expect(File.exist?(file[:file].path)).to be false
      end

      files[:font_files].each do |file|
        expect(File.exist?(file.path)).to be false
      end
    end
  end
end
