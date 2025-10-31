# frozen_string_literal: true
FactoryBot.define do
  factory :pdf_template_asset, class: "PDFTemplateFileUploads::PDFTemplateAsset" do
    survey_metadatum
    object_key { SecureRandom.uuid }
  end

  factory :pdf_css_asset, class: "PDFTemplateFileUploads::PDFTemplateAsset" do
    survey_metadatum
    object_key { "#{SecureRandom.uuid}.css" }
  end
end
