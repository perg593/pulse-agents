# frozen_string_literal: true

# Stores translations retrieved from Google Translate
# Saves on API calls and speeds up translation loading
class LocaleTranslationCache < ActiveRecord::Base
  def account
    case record_type
    when "Survey"
      Survey.find(record_id).account
    when "Question"
      Question.find(record_id).survey.account
    when "PossibleAnswer"
      PossibleAnswer.find(record_id).question.survey.account
    end
  end
end

# == Schema Information
#
# Table name: locale_translation_caches
#
#  id                     :bigint           not null, primary key
#  column                 :string
#  expected_language_code :string
#  google_language_code   :string
#  original               :string
#  record_type            :string           not null
#  translation            :string
#  record_id              :bigint           not null
#
# Indexes
#
#  index_ltc_on_record_id_and_record_type_and_column  (record_id,record_type,column)
#
