# frozen_string_literal: true
module Localization
  extend ActiveSupport::Concern

  class_methods do
    def fetch_translation_from_google(text_to_translate)
      return nil unless Rails.env.production?
      return nil unless text_to_translate.present?

      client = Google::Cloud::Translate.translation_service
      parent = client.location_path(project: 'pulse-nlp', location: 'global')

      google_response = client.translate_text(
        contents: [text_to_translate],
        target_language_code: "en",
        parent: parent
      )

      {
        translated_text: google_response.translations.first.translated_text,
        detected_language_code: google_response.translations.first.detected_language_code
      }
    end
  end

  def update_translations(force: false)
    self.class.translated_fields.each do |field|
      translate_field(field, force: force) if saved_change_to_attribute?(field) || force
    end
  end

  private

  def translate_field(field_to_translate, force: false)
    unless translation = self.class.fetch_translation_from_google(self[field_to_translate])
      return
    end

    cache_record = LocaleTranslationCache.find_by(
      record_id: id,
      record_type: self.class.name,
      column: field_to_translate
    )

    if cache_record
      cache_record.update(
        translation: translation[:translated_text],
        google_language_code: translation[:detected_language_code],
        original: saved_change_to_attribute(field_to_translate).last
      )
    else
      cache_translation(translation, field_to_translate, force: force)
    end
  end

  # This should either be executed with force: false as part of a callback, or
  # with force: true outside of callbacks
  def cache_translation(translation, translated_field, force: false)
    LocaleTranslationCache.create(
      record_id: id,
      record_type: self.class.name,
      google_language_code: translation[:detected_language_code],
      column: translated_field.to_s,
      translation: translation[:translated_text],
      original: force ? self[translated_field] : saved_change_to_attribute(translated_field).last,
      expected_language_code: expected_language_code
    )
  end
end
