# frozen_string_literal: true
module SurveyExtraAttrs
  extend ActiveSupport::Concern

  module ClassMethods
    def template_surveys
      template_account = Account.template_account

      return nil unless template_account

      excluded_attrs = %i(id survey_id created_at updated_at)
      attrs = template_account.surveys.as_json(except: [:id, :account_id, :created_at, :updated_at], include: {
                                                 first_question: {
                                                   except: excluded_attrs,
                                                   include: {possible_answers: {except: excluded_attrs}}
                                                 }, follow_up_questions: {
                                                   except: excluded_attrs,
                                                   include: {possible_answers: {except: excluded_attrs}}
                                                 }, triggers: {except: excluded_attrs}, suppressers: {except: excluded_attrs}
                                               })
      attrs.each do |attr|
        if attr.key?('first_question')
          attr['first_question_attributes'] = attr.delete('first_question')
          if attr['first_question_attributes'].key?('possible_answers')
            attr['first_question_attributes']['possible_answers_attributes'] = attr['first_question_attributes'].delete('possible_answers')
          end
        end

        if attr.key?('follow_up_questions')
          attr['follow_up_questions_attributes'] = attr.delete('follow_up_questions')

          attr['follow_up_questions_attributes'].each do |the_attr|
            the_attr['possible_answers_attributes'] = the_attr.delete('possible_answers') if the_attr.key?('possible_answers')
          end
        end

        attr['triggers_attributes'] = attr.delete('triggers') if attr.key?('triggers')
        attr['suppressers_attributes'] = attr.delete('suppressers') if attr.key?('suppressers')
      end

      attrs
    end
  end

  def active_days
    return 0 if self[:live_at].blank?
    (Time.current.to_date - live_at.to_date).to_i
  end

  def last_submission
    @last_submission ||= submissions.order(created_at: :desc).select(:created_at).first.try(:created_at).try(:strftime, '%m/%d/%Y %R').to_s
  end

  # Where is this used????
  def real_status
    expired? ? 'Expired' : status
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # Where is this used????
  def tooltip
    output_arr = []
    placeholer = '&nbsp;&nbsp;&nbsp;&nbsp;'

    trigger_hash = triggers.each_with_object({}) do |trigger, hash|
      hash[trigger.type_cd] ||= []
      hash[trigger.type_cd] << "<u>#{trigger.trigger_content}</u>"
      hash
    end

    suppresser_hash = suppressers.each_with_object({}) do |trigger, hash|
      hash[trigger.type_cd] ||= []
      hash[trigger.type_cd] << "<u>#{trigger.trigger_content}</u>"
      hash
    end

    # output_arr << "<strong>#{self.name}</strong>"
    output_arr << " Trigger If URL Contains: &nbsp;#{trigger_hash['url'].join(placeholer)}" if trigger_hash['url'].present?
    output_arr << "Trigger If Regex Matches: &nbsp;#{trigger_hash['regexp'].join(placeholer)}" if trigger_hash['regexp'].present?
    output_arr << "Trigger If URL Matches Exactly: &nbsp;#{trigger_hash['url_matches'].join(placeholer)}" if trigger_hash['url_matches'].present?
    output_arr << "Suppress If URL Contains: &nbsp;#{suppresser_hash['url'].join(placeholer)}" if suppresser_hash['url'].present?
    output_arr << "Suppress If Regex Matches: &nbsp;#{suppresser_hash['regexp'].join(placeholer)}" if suppresser_hash['regexp'].present?
    output_arr << "Suppress If URL Matches Exactly: &nbsp;#{suppresser_hash['url_matches'].join(placeholer)}" if suppresser_hash['url_matches'].present?

    output_arr.join('<br />').html_safe
  end

  # rubocop:enable Metrics/AbcSize
  #
  module Stats
    delegate :helpers, to: 'ActionController::Base'

    SUBMISSION_RATE_PRECISION = 2

    def human_submission_rate(filters: {})
      helpers.number_to_percentage(submission_rate(filters: filters) * 100, precision: 0)
    end

    def submission_rate(filters: {})
      denominator = blended_impressions_count(filters: filters)
      denominator.zero? ? 0 : (submissions_count(filters: filters).to_f / denominator).round(SUBMISSION_RATE_PRECISION)
    end

    def submissions_count(filters: {})
      submissions_scope = Submission.where(survey_id: survey_ids_for_stats).where('answers_count > 0')
      submissions_scope = Submission.filtered_submissions(submissions_scope, filters: filters)

      submissions_scope.count
    end

    def blended_impressions_count(filters: {})
      start_at = account.viewed_impressions_calculation_start_at
      date_range = filters[:date_range]

      impression_scope = Submission.where(survey_id: survey_ids_for_stats)
      impression_scope =
        if date_range.nil?
          impression_scope.where(created_at: ...start_at).or(impression_scope.viewed.where(created_at: start_at..))
        elsif date_range.first >= start_at
          impression_scope.viewed.where(created_at: date_range)
        elsif date_range.first < start_at && start_at < date_range.last
          impression_scope.where(created_at: date_range.first...start_at).or(impression_scope.viewed.where(created_at: start_at..date_range.last))
        elsif date_range.last <= start_at
          impression_scope.where(created_at: date_range)
        end

      Submission.filtered_submissions(impression_scope, filters: filters.except(:date_range)).count
    end

    def viewed_impressions_count(filters: {})
      viewed_impressions_filters = filters.dup

      # If we're looking for all-time results, it'll be much faster to start the date_range from when viewed impressions was turned on
      date_filters_supplied = viewed_impressions_filters[:date_range].present? ||
                              (viewed_impressions_filters[:to].present? && viewed_impressions_filters[:from].present?)

      unless date_filters_supplied
        viewed_impressions_filters[:date_range] = (account.viewed_impressions_enabled_at..10.hours.after)
      end

      viewed_impressions_scope = Submission.viewed.where(survey_id: survey_ids_for_stats)
      viewed_impressions_scope = Submission.filtered_submissions(viewed_impressions_scope, filters: viewed_impressions_filters)

      viewed_impressions_scope.count
    end

    def impressions_count(filters: {})
      impressions_scope = Submission.where(survey_id: survey_ids_for_stats)
      impressions_scope = Submission.filtered_submissions(impressions_scope, filters: filters)

      impressions_scope.count
    end

    def cached_impressions_count(date_range = nil)
      cache_scope(date_range).sum(:impression_count)
    end

    def cached_viewed_impressions_count(date_range = nil)
      cache_scope(date_range).sum(:viewed_impression_count)
    end

    def cached_blended_impressions_count(date_range = nil)
      cache_scope(date_range).group_by(&:applies_to_date).sum do |date, caches|
        account.viewed_impressions_calculation_start_at <= date ? caches.sum(&:viewed_impression_count) : caches.sum(&:impression_count)
      end
    end

    def cached_submissions_count(date_range = nil)
      cache_scope(date_range).sum(:submission_count)
    end

    def cached_submission_rate(date_range = nil)
      denominator = cached_blended_impressions_count(date_range)
      denominator.zero? ? 0 : (cached_submissions_count(date_range).to_f / denominator).round(SUBMISSION_RATE_PRECISION)
    end

    private

    def cache_scope(date_range)
      cache_scope = SurveySubmissionCache.where(survey_id: survey_ids_for_stats)
      cache_scope = cache_scope.where(applies_to_date: date_range) if date_range
      cache_scope
    end
  end
end
