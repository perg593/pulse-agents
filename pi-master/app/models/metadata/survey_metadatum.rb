# frozen_string_literal: true

module Metadata
  class SurveyMetadatum < Metadatum
    audited associated_with: :survey

    belongs_to :survey, class_name: "Survey", foreign_key: :owner_record_id

    has_many :pdf_template_file_uploads, class_name: "PDFTemplateFileUploads::PDFTemplateFileUpload", foreign_key: :metadatum_id

    has_one :pdf_template_html_file, class_name: "PDFTemplateFileUploads::PDFTemplateHTMLFile", foreign_key: :metadatum_id
    has_many :pdf_template_assets, class_name: "PDFTemplateFileUploads::PDFTemplateAsset", foreign_key: :metadatum_id
    has_many :pdf_template_static_pdfs, class_name: "PDFTemplateFileUploads::PDFTemplateStaticPDF", foreign_key: :metadatum_id

    validate :name_unique_in_account
    validates :name, s3_object_key: true

    def name_unique_in_account
      return unless survey
      return unless SurveyMetadatum.where(owner_record_id: survey.account.survey_ids, name: name).where.not(id: id).exists?

      errors.add(:name, "must be unique in account")
    end
  end
end

# == Schema Information
#
# Table name: metadata
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  owner_record_id :integer          not null
#
# Indexes
#
#  index_metadata_on_type_and_owner_record_id  (type,owner_record_id) UNIQUE
#
