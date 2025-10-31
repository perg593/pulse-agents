# frozen_string_literal: true

module Control
  class SurveyIndexPresenter
    include Admin::CustomAuditsHelper
    include Control::SurveysHelper
    include Rails.application.routes.url_helpers
    include Numerable

    attr_accessor :stored_filters

    def initialize(surveys, current_user, stored_filters, audits, date_range)
      @surveys = surveys
      @current_user = current_user
      @stored_filters = stored_filters
      @audits = audits
      @date_range = date_range
    end

    def dashboard_props
      survey_tag_options = @current_user.account.survey_tags.order(:name).pluck(:name).map do |tag_name|
        { value: tag_name, label: tag_name }
      end

      {
        allowSurveyNameChange: @current_user.admin?,
        allowSurveyStatusChange: @current_user.full?,
        surveys: survey_data,
        surveyStatusOptions: survey_status_options,
        tagsLink: survey_tags_path,
        surveyTagOptions: survey_tag_options,
        surveyCreatedByNameOptions: created_by_name_options,
        surveyEditedByOptions: edited_by_name_options,
        showChangeLogButton: @current_user.admin? && @audits.present?,
        cacheDetails: survey_cache_data,
        storedFilters: stored_filters
      }
    end

    def created_by_name_options
      name_options = survey_data.map do |top_level_row|
        [top_level_row[:createdByName], top_level_row[:subRows]&.map { |sub_row| sub_row[:createdByName] }]
      end.flatten.compact.uniq

      name_options.map do |name|
        { value: name, label: name.titleize }
      end
    end

    def edited_by_name_options
      updated_by_names.values.uniq.map do |name|
        { value: name, label: name.titleize }
      end
    end

    def survey_status_options
      Survey.statuses.keys.map { |status| { value: status, label: status.capitalize } }
    end

    def survey_cache_data
      return unless @current_user.admin?

      # Caching happens every 10 minutes
      num_minutes_to_next_cache = 10 - (Time.current.min % 10)

      {
        lastGlobalCacheAt: SurveySubmissionCache.last.updated_at,
        nextGlobalCache: "Next caching in #{num_minutes_to_next_cache} minutes"
      }
    end

    def survey_data
      @survey_data ||= compile_survey_data
    end

    def applied_survey_tags
      @applied_survey_tags ||= @surveys.joins(applied_survey_tags: :survey_tag).
                               pluck("surveys.id", "survey_tags.name").
                               each_with_object({}) do |(survey_id, survey_tag_name), memo|
        memo[survey_id] ||= []
        memo[survey_id] << survey_tag_name
        memo
      end

      @applied_survey_tags
    end

    def possible_answer_ids_per_survey
      @possible_answer_ids_per_survey ||= @surveys.joins(possible_answers: :question).
                                          pluck("surveys.id", "possible_answers.id").
                                          each_with_object({}) do |(survey_id, possible_answer_ids_per_survey), memo|
        memo[survey_id] ||= []
        memo[survey_id] << possible_answer_ids_per_survey
        memo
      end

      @possible_answer_ids_per_survey
    end

    def created_by_names
      @created_by_names ||= @surveys.joins(:audits).where(audits: { action: :create }).
                            joins("LEFT JOIN users ON audits.user_id = users.id").
                            pluck("surveys.id", "username", "users.first_name", "users.last_name").
                            each_with_object({}) do |(survey_id, username, first_name, last_name), memo|
        memo[survey_id] = @current_user.admin? ? username : "#{first_name} #{last_name}"
        memo
      end

      @created_by_names
    end

    def survey_locale_group_data_for_table(survey_locale_group)
      sub_rows = survey_locale_group.surveys.map do |survey|
        survey_data_for_table(survey)
      end

      total_impressions = sub_rows.sum { |sub_row| sub_row[:impressions] }
      total_submissions = sub_rows.sum { |sub_row| sub_row[:submissions] }

      last_updated_survey = survey_locale_group.surveys.order(:updated_at).last

      last_impression_at = SurveySubmissionCache.where(survey_id: survey_locale_group.survey_ids).order(last_impression_at: :desc).pick(:last_impression_at)

      last_submission_at = SurveySubmissionCache.where(survey_id: survey_locale_group.survey_ids).order(last_submission_at: :desc).pick(:last_submission_at)

      {
        type: "surveyLocaleGroup",
        id: survey_locale_group.id,
        name: survey_locale_group.name,
        numSurveys: survey_locale_group.surveys.count,
        subRows: sub_rows,
        rowLinks: action_links_for_survey_locale_group(survey_locale_group),
        impressions: total_impressions,
        submissions: total_submissions,
        submissionRate: percent_of(total_submissions, total_impressions),
        # TODO: this could be done smarter
        updatedAt: last_updated_survey.updated_at.strftime('%m/%d/%Y'),
        updatedByName: last_updated_survey.updated_by_name,
        lastImpression: last_impression_at.try(:strftime, '%m/%d/%Y %R'),
        lastSubmission: last_submission_at.try(:strftime, '%m/%d/%Y %R')
      }
    end

    def survey_data_for_table(survey)
      cached_counts = cache_data[survey.id]

      num_submissions = cached_counts&.num_submissions || 0
      num_impressions = cached_counts&.num_impressions || 0

      {
        type: "survey",
        id: survey.id,
        name: survey.name,
        status: survey.status,
        goal: survey.goal,
        updatedAt: survey.updated_at.strftime('%m/%d/%Y'),
        updatedByName: updated_by_names[survey.id] || "unavailable",
        rowLinks: action_links_for_survey(survey),
        tags: applied_survey_tags[survey.id],
        createdByName: created_by_names[survey.id] || survey.account.primary_user.name,
        possibleAnswerIds: possible_answer_ids_per_survey[survey.id],
        impressions: num_impressions,
        submissions: num_submissions,
        lastImpression: cached_counts&.last_impression_at&.strftime('%m/%d/%Y %R'),
        lastSubmission: cached_counts&.last_submission_at&.strftime('%m/%d/%Y %R'),
        submissionRate: percent_of(num_submissions, num_impressions),
        searchableContent: searchable_content_per_survey[survey.id],
        liveAt: survey.live_at&.strftime('%m/%d/%Y')
      }
    end

    private

    def searchable_content_per_survey
      @searchable_content_per_survey ||= @surveys.joins(possible_answers: :question).
                                         pluck("surveys.id", "questions.content", "possible_answers.content").
                                         each_with_object({}) do |(survey_id, question_content, possible_answer_content), memo|
        memo[survey_id] ||= []
        memo[survey_id] << [question_content, possible_answer_content]
        memo[survey_id].flatten!.uniq!
        memo
      end

      @searchable_content_per_survey
    end

    def updated_by_names
      @updated_by_names ||= @surveys.joins(:audits).
                            joins("LEFT JOIN users ON audits.user_id = users.id").
                            where.not(audits: { user_id: nil }).
                            order("audits.created_at DESC").
                            pluck("surveys.id", "users.first_name", "users.last_name").
                            each_with_object({}) do |(survey_id, first_name, last_name), memo|
        unless memo[survey_id]
          full_name = "#{first_name} #{last_name}"
          memo[survey_id] = full_name unless full_name.blank?
        end

        memo
      end

      @updated_by_names
    end

    def cache_data
      submission_cache_scope = SurveySubmissionCache.joins(:survey).where(survey: @surveys)
      submission_cache_scope = submission_cache_scope.where(applies_to_date: @date_range) if @date_range

      @cache_data ||= submission_cache_scope.select(<<~SQL).group(:survey_id).index_by(&:survey_id)
        survey_id,
        MAX(last_impression_at) AS last_impression_at,
        MAX(last_submission_at) AS last_submission_at,
        COALESCE(SUM(submission_count), 0) AS num_submissions,
        COALESCE(SUM(CASE
          WHEN applies_to_date < '#{@current_user.account.viewed_impressions_calculation_start_at}'
            THEN impression_count
          ELSE viewed_impression_count
        END), 0) AS num_impressions
      SQL

      @cache_data
    end

    def compile_survey_data
      survey_locale_groups = SurveyLocaleGroup.where(id: @surveys.pluck(:survey_locale_group_id))

      survey_data = survey_locale_groups.includes(:surveys).map do |survey_locale_group|
        survey_locale_group_data_for_table(survey_locale_group)
      end

      @surveys.where(survey_locale_group_id: nil).each do |survey|
        survey_data << survey_data_for_table(survey)
      end

      survey_data
    end

    def url_safe_date_range
      [@date_range&.first, @date_range&.last].map { |datetime| datetime&.utc&.iso8601 }
    end

    def action_links_for_survey_locale_group(survey_locale_group)
      row_links = [{ label: "Results", url: localization_report_path(survey_locale_group.id, from: url_safe_date_range.first, to: url_safe_date_range.last) }]
      row_links << { label: "Bulk Editor", url: localization_editor_path(survey_locale_group.id) } if @current_user.full?

      row_links
    end

    def action_links_for_survey(survey)
      action_links = []

      action_links << { label: @current_user.full? ? "Edit" : "View", url: edit_survey_path(survey) }
      action_links << { label: "Results", url: report_survey_path(survey, from: url_safe_date_range.first, to: url_safe_date_range.last) }

      return action_links unless @current_user.full?

      unless survey.localized?
        modal_id = "localize_modal_#{survey.id}"
        modal_path = survey_index_localization_modal_survey_path(survey, modal_id: modal_id)

        action_links << { label: "Create Group", url: modal_path, data_modal_id: modal_id }
      end

      action_links << { label: "Duplicate", action: 'duplicate', url: duplicate_survey_path(survey), method: "post",
                     confirmation_message: "Duplicate the survey?" }

      if @current_user.admin?
        modal_id = "survey_deletion_modal_#{survey.id}"
        modal_path = survey_deletion_modal_survey_path(survey)

        action_links << { label: "Delete", url: modal_path, data_modal_id: modal_id, class: "dangerous-option" }
      end

      action_links
    end
  end
end
