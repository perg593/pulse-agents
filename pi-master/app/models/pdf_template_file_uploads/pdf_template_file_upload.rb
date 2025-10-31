# frozen_string_literal: true

module PDFTemplateFileUploads
  class PDFTemplateFileUpload < ActiveRecord::Base
    belongs_to :survey_metadatum, class_name: "Metadata::SurveyMetadatum", foreign_key: :metadatum_id

    attr_accessor :tempfile

    before_validation :set_object_key

    validates :object_key, s3_object_key: true

    after_save :update_s3

    after_destroy :remove_file_from_s3

    def fetch_object_from_s3
      s3_object.get
    end

    private

    def remove_file_from_s3
      s3_object.delete
    end

    def update_s3
      return unless tempfile

      s3_object.upload_file(tempfile.path)
    end

    def s3_object
      credentials = ::Aws::Credentials.new(
        Rack::Credentials.credentials.aws[:access_key_id],
        Rack::Credentials.credentials.aws[:secret_access_key]
      )

      resource = Aws::S3::Resource.new(
        region: "us-west-2",
        credentials: credentials
      )

      resource.bucket('pi-pdf-templates').object(object_key)
    end

    def store_dir
      "#{Rails.env}/#{survey_metadatum.survey.account.identifier}/#{survey_metadatum.name}"
    end

    def set_object_key
      self.object_key ||= "#{store_dir}/#{file_name}"
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
