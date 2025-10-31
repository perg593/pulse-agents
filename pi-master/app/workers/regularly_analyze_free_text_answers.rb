# frozen_string_literal: true
class RegularlyAnalyzeFreeTextAnswers
  include Sidekiq::Worker

  def perform
    Survey.lives_with_free_text_questions.all.each(&:free_text_analyze!)
  end
end
