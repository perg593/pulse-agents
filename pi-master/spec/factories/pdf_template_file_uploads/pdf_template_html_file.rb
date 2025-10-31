# frozen_string_literal: true
FactoryBot.define do
  factory :pdf_template_html_file, class: "PDFTemplateFileUploads::PDFTemplateHTMLFile" do
    survey_metadatum

    trait :without_file do
      object_key { "#{SecureRandom.uuid}.html.erb" }
    end

    trait :with_file do
      file_name = "test.html.erb"

      tempfile { Tempfile.new(file_name) }
      file_name { file_name }
    end

    factory :pdf_template_html_file_with_file, traits: [:with_file]
    factory :pdf_template_html_file_without_file, traits: [:without_file]
  end
end
