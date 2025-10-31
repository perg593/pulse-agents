# frozen_string_literal: true

module Admin
  class PDFTemplatePresenter
    def initialize(survey)
      @survey = survey
    end

    def props
      {
        templateFile: template_file,
        assetFiles: asset_files,
        staticPdfFiles: static_pdf_files,
        survey: {
          name: @survey.name,
          id: @survey.id
        }
      }
    end

    def self.file_prop(file_upload)
      prop = {
        id: file_upload.id,
        name: file_upload.file_name
      }

      prop[:position] = file_upload.position if file_upload.try(:position)

      prop
    end

    private

    def template_file
      file_upload = @survey.metadatum.pdf_template_html_file

      return unless file_upload

      self.class.file_prop(file_upload)
    end

    def asset_files
      @survey.metadatum.pdf_template_assets.map do |file_upload|
        self.class.file_prop(file_upload)
      end
    end

    def static_pdf_files
      files = @survey.metadatum.pdf_template_static_pdfs.map do |file_upload|
        self.class.file_prop(file_upload)
      end

      files.sort_by { |file| file[:position] }
    end
  end
end
