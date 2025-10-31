# frozen_string_literal: true
FactoryBot.define do
  factory :pdf_template_static_pdf, class: "PDFTemplateFileUploads::PDFTemplateStaticPDF" do
    survey_metadatum

    object_key { "#{SecureRandom.uuid}.pdf" }
  end
end
