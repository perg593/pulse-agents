# frozen_string_literal: true

module PDFTemplateFileUploads
  class PDFTemplateHTMLFile < PDFTemplateFileUpload
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
