# frozen_string_literal: true

class FreeTextTranslator
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  sidekiq_options queue: :console

  def perform
    return if %w(development test).include? environment

    @client = Google::Cloud::Translate.translation_service
    @parent = @client.location_path(project: 'pulse-nlp', location: 'global')

    # this worker is executed every 5 minutes
    Answer.where("created_at > ?", 5.minutes.ago).each do |answer|
      text = answer.text_answer

      next if text.blank? || english_text?(text)

      translation = translate_to_english(text)

      answer.update(translated_answer: translation)
    end
  end

  private

  def english_text?(text)
    response = @client.detect_language(parent: @parent, content: text, mime_type: 'text/plain')

    # https://googleapis.dev/ruby/google-cloud-translate/latest/Google/Cloud/Translate/V3/DetectLanguageResponse.html
    # The most probable language comes first
    response.languages.first.language_code == 'en'
  rescue StandardError => e
    report_to_rollbar("Google::Cloud::Translate Detection error: #{e}", free_text: text)
    true # early return the job
  end

  def translate_to_english(text)
    response = @client.translate_text(parent: @parent, contents: [text], target_language_code: 'en', mime_type: 'text/plain')

    response.translations.first.translated_text
  rescue StandardError => e
    report_to_rollbar("Google::Cloud::Translate Translation error: #{e}", free_text: text)
    ''
  end
end
