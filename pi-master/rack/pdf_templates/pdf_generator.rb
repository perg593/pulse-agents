# frozen_string_literal: true

require_relative '../pdf_templates/template_renderer'
require_relative '../pdf_templates/file_fetcher'

module Rack
  module PdfTemplates
    class PDFGenerator
      include Rack::PiLogger

      # Generates a PDF using user-upload template files and response data
      # survey_id - the id of the survey
      # template_submission - the response data
      def generate(survey_id, template_submission = nil)
        log "Generating PDF for survey #{survey_id}", "DEBUG"

        file_fetcher = FileFetcher.new
        files_by_type = file_fetcher.fetch_files(survey_id)

        static_pdf_files = files_by_type[:pdf_files]

        renderer = Rack::PdfTemplates::TemplateRenderer.new(
          files_by_type[:template_file],
          css_files: files_by_type[:css_files],
          image_files: files_by_type[:image_files],
          font_files: files_by_type[:font_files],
          answer_info: template_submission
        )

        log "Rendering template", "DEBUG"
        rendered_template = renderer.render_template
        log "Rendered: #{rendered_template}", "DEBUG"

        log "Generating PDF from template", "DEBUG"
        pdf = WickedPdf.new.pdf_from_string(rendered_template, enable_local_file_access: true, page_size: 'Letter', disable_javascript: true)

        if static_pdf_files.empty?
          pdf
        else
          log "Combining PDF with static PDFs", "DEBUG"
          collate_pdfs(pdf, static_pdf_files).to_pdf
        end
      ensure
        file_fetcher.clean_up_files
      end

      private

      def collate_pdfs(dynamic_pdf, static_pdf_files)
        combined_pdf = ::CombinePDF.new

        sorted_files = static_pdf_files.sort_by { |file| file[:metadata]["position"] }
        prepended, appended = sorted_files.partition { |file| file[:metadata]["position"].negative? }

        prepended.each do |static_pdf_file|
          combined_pdf << ::CombinePDF.load(static_pdf_file[:file].path)
        end

        combined_pdf << ::CombinePDF.parse(dynamic_pdf)

        appended.each do |static_pdf_file|
          combined_pdf << ::CombinePDF.load(static_pdf_file[:file].path)
        end

        combined_pdf
      end
    end
  end
end
