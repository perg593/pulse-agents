# frozen_string_literal: true

module PDFTemplateFileUploads
  class PDFTemplateStaticPDF < PDFTemplateFileUpload
    before_create :set_default_position, unless: :position

    after_destroy :reorder_remaining_static_pdf_files

    # negative means before the template
    # positive means after the template
    def position
      metadata["position"]
    end

    def position=(new_position)
      metadata.merge!(position: new_position)
    end

    private

    def set_default_position
      other_static_pdfs = survey_metadatum.pdf_template_static_pdfs

      next_position = other_static_pdfs.empty? ? 1 : other_static_pdfs.map(&:position).max + 1

      metadata.merge!(position: next_position)
    end

    def reorder_remaining_static_pdf_files
      other_ordered_file_uploads = survey_metadatum.pdf_template_static_pdfs.where.not(id: id).sort_by(&:position)

      # update positions of other file uploads
      before_template_files, after_template_files = other_ordered_file_uploads.partition { |file_upload| file_upload.position.negative? }

      before_template_files.each_with_index do |file_upload, i|
        new_position = (before_template_files.size * -1) + i
        file_upload.position = new_position
      end

      after_template_files.each_with_index do |file_upload, i|
        new_position = i + 1
        file_upload.position = new_position
      end

      (before_template_files + after_template_files).each(&:save!)
    end
  end
end

# == Schema Information
#
# Table name: pdf_template_file_uploads
#
#  id           :bigint           not null, primary key
#  file_name    :string
#  metadata     :jsonb
#  object_key   :string           not null
#  type         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  metadatum_id :bigint           not null
#
# Indexes
#
#  index_pdf_template_file_uploads_on_metadatum_id  (metadatum_id)
#  index_pdf_template_file_uploads_on_object_key    (object_key) UNIQUE
#
