# frozen_string_literal: true

class Answer < ApplicationRecord
  include QrveySynchronization

  belongs_to :submission, counter_cache: true
  belongs_to :possible_answer, optional: true
  belongs_to :question, optional: true
  has_one :device, through: :submission
  has_one :survey, through: :question
  has_many :page_events, through: :device

  has_many :applied_tags
  has_many :tags, through: :applied_tags, after_add: :delete_outdated_automation_failure_tag

  scope :auto_tag_eligible, -> { where(question_type: :free_text_question).where.not(<<-SQL) }
    EXISTS(SELECT 1 FROM applied_tags WHERE applied_tags.answer_id = answers.id)
  SQL

  enum question_type: { single_choice_question: 0, free_text_question: 1, custom_content_question: 2, multiple_choices_question: 3, slider_question: 4 }

  before_validation :set_question_attributes
  after_destroy :delete_submission_if_answers_count_zero

  delegate :content, to: :question, prefix: true, allow_nil: true
  delegate :content, to: :possible_answer, prefix: true, allow_nil: true
  delegate :device_id, to: :submission, allow_nil: true
  delegate :url, to: :submission, allow_nil: true
  delegate :ip_address, to: :submission, allow_nil: true
  delegate :user_agent, to: :submission, allow_nil: true
  delegate :os, to: :submission, allow_nil: true
  delegate :browser, to: :submission, allow_nil: true
  delegate :browser_version, to: :submission, allow_nil: true
  delegate :previous_surveys, to: :submission, allow_nil: true
  delegate :custom_data, to: :submission, allow_nil: true

  def free_text_analyze!
    if text_answer.nil? || text_answer == ""
      update(analyzed: true)
      return
    end

    res = sentiment_and_entities

    update(keyword_extraction: extract_keywords,
           sentiment: res.sentiment,
           entities: res.entities,
           analyzed: true)
  end

  def extract_keywords
    rake = RakeText.new
    keyword_extraction = rake.analyse(text_answer.gsub("don't", "dont"), RakeText.SMART)
    keyword_extraction = rearrange_keyword_extraction(keyword_extraction) if keyword_extraction

    keyword_extraction
  end

  # https://cloud.google.com/natural-language/docs/languages
  SUPPORTED_ENTITY_ANALYSIS_LANGUAGES = %w(zh zh-Hant en fr de it ja ko pt ru es).freeze
  SUPPORTED_SENTIMENT_ANALYSIS_LANGUAGES = %w(ar zh zh-Hant nl en fr de id it ja ko pt es th tr vi).freeze

  def google_nlp
    @google_nlp ||= Google::Cloud::Language.language_service
  end

  def detected_language_code
    if @detected_language_code.blank?
      google_translate = Google::Cloud::Translate.translation_service
      parent = google_translate.location_path(project: 'pulse-nlp', location: 'global')

      google_response = google_translate.detect_language(
        content: text_answer,
        parent: parent
      )

      @detected_language_code = google_response.languages.first.language_code
    end

    @detected_language_code
  end

  def extract_sentiment
    return {} unless SUPPORTED_SENTIMENT_ANALYSIS_LANGUAGES.include? detected_language_code

    begin
      sentiment_response = google_nlp.analyze_sentiment({document: {content: text_answer, type: :PLAIN_TEXT}})
      sentiment_response.document_sentiment.to_h
    rescue GRPC::InvalidArgument, Google::Cloud::InvalidArgumentError => e
      error_msg = "Google::Cloud::Language Error analyzing sentiment #{e}"
      Rails.logger.info(error_msg + " - text_answer: #{text_answer}")
      Rollbar.error(error_msg, text_answer: text_answer)
      {}
    end
  end

  def extract_entities
    return {} unless SUPPORTED_ENTITY_ANALYSIS_LANGUAGES.include? detected_language_code

    begin
      entities_response = google_nlp.analyze_entities({document: {content: text_answer, type: :PLAIN_TEXT}})
      entities_response.entities.map { |entity| { name: entity.name, type: entity.type } }
    rescue GRPC::InvalidArgument, Google::Cloud::InvalidArgumentError => e
      error_msg = "Google::Cloud::Language Error analyzing entities: #{e}"
      Rails.logger.info(error_msg + " - text_answer: #{text_answer}")
      Rollbar.error(error_msg, text_answer: text_answer)
      {}
    end
  end

  # score: Quality of emotion: (-1.0, 1.0) low means negative, high means positive
  # magnitude: Intensity of emotion: (0.0, +inf) high means conclusive, low means inconclusive
  def human_friendly_sentiment
    return unless sentiment

    magnitude = sentiment["magnitude"]
    score = sentiment["score"]

    if magnitude.nil? || score.nil?
      nil
    elsif score >= 0.5
      if magnitude >= 0.4
        "Very Positive"
      else
        "Positive"
      end
    elsif score <= -0.5
      if magnitude >= 0.4
        "Very Negative"
      else
        "Negative"
      end
    else
      "Neutral"
    end
  end

  def sentiment_and_entities
    res = Struct.new(:sentiment, :entities)

    return res.new(nil, nil) if Rails.env.test?

    res.new(extract_sentiment, extract_entities)
  end

  def extracted_keywords
    return {} if keyword_extraction.nil?

    ke = keyword_extraction
    ke = JSON.parse(keyword_extraction.to_s) unless ke.is_a?(Array)
    ke.inject({}) { |a, b| a.merge(b["text"] => b["relevance"].to_f) }
  end

  def device_data
    return nil unless submission

    account_id = submission.survey.try(:account_id)
    device_id = submission.device.try(:id)

    DeviceData.where(account_id: account_id, device_id: device_id).try(:last).try(:device_data)
  end

  def qualified_for_tag_automation?
    text_answer.present? && tags.count.zero?
  end

  def text_of_response
    text_answer || possible_answer.content
  end

  def next_question_id
    possible_answer&.next_question_id || question.next_question_id || question.free_text_next_question_id
  end

  def self.filtered_answers(answer_scope, filters: {})
    return answer_scope unless filters.present?

    filters.each do |field, value|
      answer_scope = case field
      when :date_range
        answer_scope.where(created_at: value)
      when :device_types
        answer_scope.joins(:submission).where(submissions: { device_type: value })
      when :market_ids
        answer_scope.joins(:question).where(questions: { survey_id: value })
      when :completion_urls
        answer_scope.joins(:submission).where(CompletionUrlFilter.combined_sql(value))
      when :possible_answer_id
        submission_ids = Answer.where(possible_answer_id: value).pluck(:submission_id)
        answer_scope.joins(:submission).where(submissions: { id: submission_ids })
      when :pageview_count, :visit_count
        answer_scope.joins(:submission).where(value.to_sql)
      else
        Rails.logger.info "Unrecognized filter #{field}"
        answer_scope
      end
    end

    answer_scope
  end

  def self.answers_count(answer_scope, ignore_multiple_type_dup: false, filters: {})
    answer_scope = filtered_answers(answer_scope, filters: filters)
    answer_scope = answer_scope.select(:submission_id).distinct(:submission_id) if ignore_multiple_type_dup
    answer_scope.count
  end

  private

  def rearrange_keyword_extraction(keyword_extraction)
    result = []

    keyword_extraction.each_pair do |k, v|
      result << { "relevance" => (v.to_f / (k.length ** 2)).to_s, "text" => k }
    end

    result
  end

  def set_question_attributes
    self[:question_id] ||= possible_answer.try(:question_id)
    self[:question_type] ||= question&.question_type
  end

  def delete_outdated_automation_failure_tag(_tag)
    return if tags.count < 2
    return unless automation_failure_tag = tags.find_by(name: Tag::AUTOMATION_PLACEHOLDER_NAME)
    applied_tags.find_by(tag: automation_failure_tag).destroy
  end

  def delete_submission_if_answers_count_zero
    submission.destroy if submission&.answers_count&.zero?
  end
end

# == Schema Information
#
# Table name: answers
#
#  id                 :integer          not null, primary key
#  analyzed           :boolean          default(FALSE)
#  entities           :jsonb
#  keyword_extraction :jsonb
#  negative_sentiment :float
#  positive_sentiment :float
#  question_type      :integer
#  sentiment          :jsonb
#  text_answer        :text
#  translated_answer  :string
#  created_at         :datetime
#  updated_at         :datetime
#  possible_answer_id :integer
#  question_id        :integer
#  submission_id      :integer
#
# Indexes
#
#  index_answers_on_created_at                                      (created_at)
#  index_answers_on_possible_answer_id                              (possible_answer_id)
#  index_answers_on_question_id                                     (question_id)
#  index_answers_on_sub_id_and_q_id_and_pa_id_and_null_text_answer  (submission_id,question_id,possible_answer_id) UNIQUE WHERE (text_answer IS NULL)
#  index_answers_on_sub_id_and_q_id_except_for_multi_choice         (submission_id,question_id) UNIQUE WHERE (question_type <> 3)
#  index_answers_on_submission_id                                   (submission_id)
#  index_answers_on_updated_at                                      (updated_at)
#
