# frozen_string_literal: true

module Control
  class SurveyReportPresenter
    include Rails.application.routes.url_helpers
    include TrendReportCalculations

    COLOR_PALETTE = %w(#9B62A7 #6F4C9B #5568B8 #4D8AC6 #549EB3 #60AB9E #77B77D #A6BE54 #E49C39 #E67932 #95211B).freeze

    attr_accessor :filters

    def initialize(survey, current_user:, survey_locale_group: nil, filters: {})
      @survey = survey
      @survey_locale_group = survey_locale_group
      @filters = filters
      @current_user = current_user
    end

    def report_component_params
      return_params = {
        data: overall_data,
        numDaysActive: @survey.active_days,
        filteringUrl: ajax_report_survey_path(@survey.id),
        trendParams: trend_report_params,
        includeAIAnalysis: @survey.account.ai_summaries_enabled
      }

      background_data_params = @filters.deep_dup
      background_data_params[:completion_urls] = background_data_params[:completion_urls].map(&:to_json) if background_data_params[:completion_urls]
      background_data_params[:pageview_count] = background_data_params[:pageview_count].to_json if background_data_params[:pageview_count]
      background_data_params[:visit_count] = background_data_params[:visit_count].to_json if background_data_params[:visit_count]

      if @survey_locale_group
        return_params.merge(
          {
            reportDataUrl: localization_report_metrics_path(@survey_locale_group.id, background_data_params),
            reportSummariesUrl: localization_report_stats_path(@survey_locale_group.id, background_data_params)
          }
        )
      else
        return_params.merge(
          {
            reportDataUrl: background_report_metrics_survey_path(@survey.id, background_data_params),
            reportSummariesUrl: background_report_stats_survey_path(@survey.id, background_data_params)
          }
        )
      end
    end

    def trend_report_params
      @trend_report_params = {
        questions: {},
        timestamp: Time.current.to_i * 1000,
        updateUrl: trend_report_data_survey_path(@survey.id)
      }

      questions = @survey.questions.select { |question| question.possible_answers.present? }

      aggregate_data = @survey_locale_group

      questions.each do |question|
        record = aggregate_data ? question.question_locale_group : question
        @trend_report_params[:questions][question.id] = aggregate_data ? localization_chart_data(record) : single_question_chart_data(record)
      end

      @trend_report_params
    end

    def available_markets
      return nil unless @survey_locale_group

      @survey_locale_group.surveys.order(:name).map do |survey|
        { id: survey.id, label: survey.name }
      end
    end

    def completion_url_matchers
      [
        { label: "URL contains", value: "contains" },
        { label: "URL does not contain", value: "does_not_contain"},
        { label: "URL Regex matches", value: "regex"}
      ]
    end

    def comparators
      [
        { label: "<", value: Filters::COMPARATOR_LESS_THAN },
        { label: "<=", value: Filters::COMPARATOR_LESS_THAN_OR_EQUAL_TO },
        { label: "=", value: Filters::COMPARATOR_EQUAL_TO },
        { label: ">=", value: Filters::COMPARATOR_GREATER_THAN_OR_EQUAL_TO },
        { label: ">", value: Filters::COMPARATOR_GREATER_THAN }
      ]
    end

    def filters_for_export_link
      filters = @filters.deep_dup
      filters[:completion_urls] = filters[:completion_urls].map(&:to_json) if filters[:completion_urls]
      filters
    end

    def scheduled_report_links
      scheduled_report_ids = []
      scheduled_report_ids << ScheduledReport.where(account_id: @survey.account, all_surveys: true).pluck(:id)
      scheduled_report_ids << ScheduledReportSurvey.where(survey_id: @survey.id).pluck(:scheduled_report_id)
      scheduled_report_ids << ScheduledReportSurveyLocaleGroup.where(survey_locale_group: @survey.survey_locale_group).pluck(:scheduled_report_id)

      scheduled_report_ids.flatten!

      relevant_scheduled_reports = ScheduledReport.where(id: scheduled_report_ids).to_a

      edit_links = relevant_scheduled_reports.map do |scheduled_report|
        {
          "url" => edit_scheduled_report_path(scheduled_report.id),
          "label" => scheduled_report.name
        }
      end

      {
        "edit" => edit_links,
        "index" => {
          "url" => scheduled_reports_path,
          "label" => "See all scheduled reports"
        },
        "new" => {
          "url" => new_scheduled_report_path,
          "label" => "Schedule A Report"
        }
      }
    end

    def filter_sidebar_component_params
      params = {
        availableMarkets: available_markets,
        completionUrlMatchers: completion_url_matchers,
        scheduledReportLinks: scheduled_report_links,
        comparators: comparators,
        surveyId: @survey.id,
        answerCount: Answer.answers_count(@survey.answers, filters: @filters),
        nextInsightsEnabled: @survey.account.next_insights_agent_enabled,
        aiReadoutFeatures: ai_readout_features,
        currentAiOutlineJob: current_ai_outline_job
      }

      # Add prompt templates for superadmins
      if @current_user&.admin?
        prompt_templates = PromptTemplate.order(:name)
        params[:promptTemplates] = prompt_templates.as_json(only: [:id, :name, :content, :is_default])

        # Set initial prompt selection and text
        default_template = prompt_templates.find_by(is_default: true)
        if default_template
          params[:initialPromptVersion] = default_template.id
          params[:initialPromptText] = default_template.content
        end
      end

      params
    end

    def ai_readout_features
      if @current_user.admin?
        {
          canSelectPrompt: true,
          canEditPrompts: true,
          canGenerateOutlines: true,
          canEditOutlines: true
        }
      else
        {
          canSelectPrompt: false,
          canEditPrompts: false,
          canGenerateOutlines: false,
          canEditOutlines: false
        }
      end
    end

    def current_ai_outline_job
      # Find the most recent job that's either in progress or recently completed
      recent_job = @survey.ai_outline_jobs.
                   where(status: [:generating_outline, :outline_completed, :generating_gamma, :completed]).
                   or(@survey.ai_outline_jobs.where(status: :failed, created_at: 24.hours.ago..)).
                   order(created_at: :desc).
                   first

      return nil unless recent_job

      {
        id: recent_job.id,
        status: recent_job.status,
        outline_content: recent_job.outline_content,
        error_message: recent_job.error_message,
        created_at: recent_job.created_at,
        started_at: recent_job.started_at,
        completed_at: recent_job.completed_at,
        gamma_generation_id: recent_job.gamma_generation_id,
        gamma_url: recent_job.gamma_url,
        completion_date: recent_job.gamma_completed_at || recent_job.completed_at
      }
    end

    private

    def single_question_chart_data(question)
      series = question.possible_answers.sort_by_position.map do |possible_answer|
        {
          id: possible_answer.id,
          name: possible_answer.content,
          data: trend_report_data(question, possible_answer),
          color: color(question.id, possible_answer)
        }
      end

      num_responses = series.sum { |possible_answer| possible_answer[:data].sum(&:last) }

      chart_title = question.content
      chart_id = question.id

      {seriesData: series, title: chart_title, numResponses: num_responses, chartId: chart_id}
    end

    def localization_chart_data(question_locale_group)
      ordered_possible_answer_locale_groups = question_locale_group.base_question.possible_answers.sort_by_position.map(&:possible_answer_locale_group)
      series = ordered_possible_answer_locale_groups.map do |possible_answer_locale_group|
        {
          id: possible_answer_locale_group.id,
          name: possible_answer_locale_group.name,
          data: trend_report_data(question_locale_group, possible_answer_locale_group),
          color: color(question_locale_group.id, possible_answer_locale_group)
        }
      end

      num_responses = series.sum { |possible_answer_locale_group| possible_answer_locale_group[:data].sum(&:last) }

      chart_title = question_locale_group.name
      chart_id = question_locale_group.id

      {seriesData: series, title: chart_title, numResponses: num_responses, chartId: chart_id}
    end

    def params_for_question(question)
      if question.custom_content_question?
        params_for_custom_content_question(question)
      elsif question.free_text_question?
        params_for_free_text_question(question)
      elsif @survey_locale_group
        params_for_question_localization(question)
      else
        params_for_question_single(question)
      end
    end

    def params_for_question_localization(question)
      possible_answers = question.possible_answers.map do |possible_answer|
        {
          id: possible_answer.possible_answer_locale_group_id,
          content: possible_answer.content,
          answerRate: possible_answer.possible_answer_locale_group.answer_rate(filters: @filters).to_f.round,
          nextQuestionId: possible_answer.next_question_id,
          answerCount: possible_answer.possible_answer_locale_group.answers_count(filters: @filters),
          color: color(question.id, possible_answer.possible_answer_locale_group),
          colorUpdateUrl: "/possible_answer_locale_groups/#{possible_answer.possible_answer_locale_group_id}/update_color"
        }
      end

      {
        responseCount: question.question_locale_group.answers_count(ignore_multiple_type_dup: true, filters: @filters),
        ungroupedResponseCount: question.question_locale_group.answers_count(ignore_multiple_type_dup: false, filters: @filters),
        possibleAnswers: possible_answers,
        question: {
          id: question.id,
          type: question.question_type,
          content: question.content,
          nextQuestionId: question.next_question_id
        }
      }
    end

    def params_for_question_single(question)
      possible_answer_rates = question.answer_rates(filters: @filters)

      possible_answers = possible_answer_rates.map do |possible_answer_rate|
        {
          id: possible_answer_rate[:possible_answer].id,
          content: possible_answer_rate[:possible_answer].content,
          answerRate: (possible_answer_rate[:answer_rate] * 100).to_f.round,
          nextQuestionId: possible_answer_rate[:possible_answer].next_question_id,
          answerCount: possible_answer_rate[:answers_count],
          color: color(question.id, possible_answer_rate[:possible_answer]),
          colorUpdateUrl: "/possible_answers/#{possible_answer_rate[:possible_answer].id}/update_color"
        }
      end

      {
        responseCount: question.answers_count(:group_submission_id, filters: @filters),
        ungroupedResponseCount: question.answers_count(filters: @filters),
        possibleAnswers: possible_answers,
        question: {
          id: question.id,
          type: question.question_type,
          content: question.content,
          nextQuestionId: question.next_question_id
        }
      }
    end

    def tag_frequency_data(question)
      data = question.tags.includes(:applied_tags).map do |tag|
        {
          tag_name: tag.name,
          num_applied_tags: tag.applied_tags.count
        }
      end

      data.filter! { |datum| datum[:num_applied_tags].positive? }
      data.sort_by! { |datum| datum[:num_applied_tags] }

      data.reverse!
    end

    def params_for_free_text_question(question)
      num_applied_tags = question.applied_tags.count

      tags = tag_frequency_data(question).map do |tags_datum|
        tag_rate = (tags_datum[:num_applied_tags] * 100.0 / num_applied_tags).round

        {
          count: tags_datum[:num_applied_tags],
          name: tags_datum[:tag_name],
          rate: tag_rate
        }
      end

      response_sample_limit = 100

      last_summarization_job = question.ai_summarization_jobs.done.last

      ai_analysis = if last_summarization_job
        {
          datetime: last_summarization_job.created_at.strftime("%m/%d/%Y %H:%M"),
          summary: last_summarization_job.summary,
          status: last_summarization_job.status
        }
      end

      {
        responseCount: question.answers_count(:group_submission_id, filters: @filters),
        responseSample: question.answers.last(response_sample_limit).pluck(:text_answer),
        tags: tags,
        aiAnalysis: ai_analysis,
        question: {
          id: question.id,
          type: question.question_type,
          content: question.content,
          nextQuestionId: question.next_question_id
        }
      }
    end

    def params_for_custom_content_question(question)
      entire_link_click_count = question.custom_content_link_click_count(filters: @filters)
      links = question.custom_content_links.map do |custom_content_link|
        link_click_count = custom_content_link.click_count(filters: @filters) # TODO: N+1
        link_click_rate = entire_link_click_count.zero? ? 0 : (link_click_count * 100 / entire_link_click_count).round
        {
          id: custom_content_link.id,
          text: custom_content_link.link_text,
          url: custom_content_link.link_url,
          clickCount: link_click_count,
          clickRate: link_click_rate,
          color: color(question, custom_content_link),
          colorUpdateUrl: update_color_custom_content_link_path(custom_content_link.id)
        }
      end
      {
        links: links,
        entireLinkClickCount: entire_link_click_count,
        question: {
          id: question.id,
          type: question.question_type,
          content: question.content
        }
      }
    end

    def overall_data
      unless @overall_data
        @overall_data = []

        @survey.questions.includes(:custom_content_links).each do |question|
          next if question.custom_content_question? && skip_custom_content_question?(question)
          @overall_data << params_for_question(question)
        end
      end

      @overall_data
    end

    def color(question_level_id, possible_answer_level_record)
      key = "#{question_level_id}_#{possible_answer_level_record.id}"

      @color_cache ||= {}

      @color_cache[key] ||= possible_answer_level_record.report_color

      @color_index ||= 0
      unless @color_cache[key]
        @color_cache[key] = COLOR_PALETTE[@color_index]
        @color_index += 1
        @color_index = 0 if @color_index >= COLOR_PALETTE.size
      end

      @color_cache[key]
    end

    def skip_custom_content_question?(question)
      return true if question.custom_content_links.empty?

      @account ||= @survey&.account || @survey_locale_group.account
      !@account.custom_content_link_click_enabled?
    end
  end
end
