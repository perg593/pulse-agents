# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

describe Control::SurveyReportPresenter do
  include Rails.application.routes.url_helpers

  before do
    Submission.delete_all
    Answer.delete_all
    ScheduledReport.delete_all
    ScheduledReportSurvey.delete_all
    ScheduledReportSurveyLocaleGroup.delete_all
  end

  let(:localized) { false }

  describe "AI analysis" do
    before do
      survey = create(:survey_without_question)
      question = create(:free_text_question, survey: survey)
      submission = create(:submission, survey: survey)
      create(:free_text_answer, question: question, submission: submission)

      @ai_summarization_job = create(:ai_summarization_job, question: question, status: :done, summary: FFaker::Lorem.phrase)

      @presenter = described_class.new(survey, current_user: create(:user, account: survey.account))
    end

    it "returns an aiAnalysis object" do
      analysis_data = @presenter.report_component_params[:data][0][:aiAnalysis]

      expect(analysis_data[:datetime]).to eq(@ai_summarization_job.created_at.strftime("%m/%d/%Y %H:%M"))
      expect(analysis_data[:summary]).to eq(@ai_summarization_job.summary)
    end
  end

  describe "completion_url_matchers" do
    it "provides the expected matchers" do
      presenter = described_class.new(create(:survey), current_user: create(:user))

      matchers = presenter.completion_url_matchers

      expected_matchers = [
        { label: "URL contains", value: "contains" },
        { label: "URL does not contain", value: "does_not_contain"},
        { label: "URL Regex matches", value: "regex"}
      ]

      expect(matchers).to eq expected_matchers
    end
  end

  describe "comparators" do
    it "provides the expected comparators" do
      presenter = described_class.new(create(:survey), current_user: create(:user))

      comparators = presenter.comparators
      expect(comparators.length).to eq Filters::ComparatorFilter::VALID_COMPARATORS.length

      expected_labels = ["<", "<=", "=", ">=", ">"]
      expected_values = Filters::ComparatorFilter::VALID_COMPARATORS

      comparators.each_with_index do |comparator, i|
        expect(comparator.keys).to eq %i(label value)
        expect(comparator[:label]).to eq expected_labels[i]
        expect(comparator[:value]).to eq expected_values[i]
      end
    end
  end

  describe "filter_sidebar_component_params" do
    let(:account) { create(:account, next_insights_agent_enabled: true) }
    let(:survey) { create(:survey, account: account) }
    let(:current_user) { create(:user, account: account) }
    let(:presenter) { described_class.new(survey, current_user: current_user) }
    let(:params) { presenter.filter_sidebar_component_params }

    it "returns all expected keys" do
      expect(params.keys).to contain_exactly(:availableMarkets, :completionUrlMatchers, :scheduledReportLinks, :comparators, :surveyId, :answerCount, :nextInsightsEnabled, :aiReadoutFeatures, :currentAiOutlineJob)
    end

    it "includes the survey ID" do
      expect(params[:surveyId]).to eq(survey.id)
    end

    it "includes the next insights enabled flag" do
      expect(params[:nextInsightsEnabled]).to eq(account.next_insights_agent_enabled)
    end

    it "includes the answer count" do
      answer_count = rand(10)
      allow(Answer).to receive(:answers_count).and_return(answer_count)
      expect(params[:answerCount]).to eq(answer_count)
    end

    it "includes the current AI outline job" do
      # Create a recent job that should be returned as current
      recent_job = create(:ai_outline_job, survey: survey, status: :generating_outline, created_at: 10.minutes.ago)

      # Reload the presenter to get the updated job
      presenter = described_class.new(survey, current_user: current_user)
      params = presenter.filter_sidebar_component_params

      expect(params[:currentAiOutlineJob]).to eq(presenter.send(:current_ai_outline_job))
    end

    it "includes completion_date in current AI outline job when job is completed" do
      # Create a completed job with both outline and gamma completion dates
      completed_at = 1.hour.ago
      gamma_completed_at = 30.minutes.ago
      recent_job = create(:ai_outline_job,
                          survey: survey,
                          status: :completed,
                          completed_at: completed_at,
                          gamma_completed_at: gamma_completed_at,
                          created_at: 2.hours.ago)

      # Reload the presenter to get the updated job
      presenter = described_class.new(survey, current_user: current_user)
      params = presenter.filter_sidebar_component_params

      current_job = params[:currentAiOutlineJob]
      expect(current_job[:completion_date]).to be_present
      expect(current_job[:completion_date]).to be_within(1.second).of(gamma_completed_at) # Should prioritize gamma_completed_at
    end

    it "includes completion_date in current AI outline job when only outline is completed" do
      # Create a job with only outline completion (no gamma)
      completed_at = 1.hour.ago
      recent_job = create(:ai_outline_job,
                          survey: survey,
                          status: :outline_completed,
                          completed_at: completed_at,
                          gamma_completed_at: nil,
                          created_at: 2.hours.ago)

      # Reload the presenter to get the updated job
      presenter = described_class.new(survey, current_user: current_user)
      params = presenter.filter_sidebar_component_params

      current_job = params[:currentAiOutlineJob]
      expect(current_job[:completion_date]).to be_present
      expect(current_job[:completion_date]).to be_within(1.second).of(completed_at) # Should fall back to completed_at when gamma_completed_at is nil
    end

    it "returns nil for currentAiOutlineJob when no recent jobs exist" do
      # Create an old job that shouldn't be returned as current
      old_job = create(:ai_outline_job, survey: survey, status: :failed, created_at: 25.hours.ago)

      # Reload the presenter to get the updated job
      presenter = described_class.new(survey, current_user: current_user)
      params = presenter.filter_sidebar_component_params

      expect(params[:currentAiOutlineJob]).to be_nil
    end
  end

  describe "filtering" do
    before do
      account = create(:account, custom_content_link_click_enabled: true)
      @survey = create(:survey, account: account)
      @current_user = create(:user, account: account)
      @date_range = nil
      @question = @survey.questions.first
      @custom_content_question = create(:custom_content_question, survey: @survey)
      @custom_content_link = create(:custom_content_link, custom_content_question: @custom_content_question,
                                    link_text: FFaker::Lorem.sentence, link_url: FFaker::Internet.http_url)
      @random_custom_content_link = create(:custom_content_link, custom_content_question: create(:custom_content_question),
                                    link_text: FFaker::Lorem.sentence, link_url: FFaker::Internet.http_url)
    end

    def it_includes_filters_in_background_report_metrics_survey_path(filters, report_component_params)
      if filters[:completion_urls]
        expected_filter_params = filters[:completion_urls].map(&:to_json)
        expect(report_component_params[:reportDataUrl]).to eq(background_report_metrics_survey_path(@survey.id, completion_urls: expected_filter_params))
      elsif filters[:pageview_count]
        expected_filter_params = filters[:pageview_count].to_json
        expect(report_component_params[:reportDataUrl]).to eq(background_report_metrics_survey_path(@survey.id, pageview_count: expected_filter_params))
      elsif filters[:visit_count]
        expected_filter_params = filters[:visit_count].to_json
        expect(report_component_params[:reportDataUrl]).to eq(background_report_metrics_survey_path(@survey.id, visit_count: expected_filter_params))
      end
    end

    # rubocop:disable Metrics/AbcSize It's complicated
    def it_filters_the_results(filters)
      presenter = described_class.new(@survey, survey_locale_group: @survey_locale_group, filters: filters, current_user: @current_user)
      report_component_params = presenter.report_component_params

      it_includes_filters_in_background_report_metrics_survey_path(filters, report_component_params) if filters

      @survey.questions.sort_by_position.each_with_index do |question, question_index|
        expect_custom_content_params(report_component_params[:data][question_index], filters) and next if question.custom_content_question?

        question_bar_chart_data = report_component_params[:data][question_index]
        expect(question_bar_chart_data[:responseCount]).to eq(question.answers_count(filters: filters))

        question_trend_chart_data = presenter.trend_report_params[:questions][question.id]
        expect(question_trend_chart_data[:numResponses]).to eq(question.answers_count(filters: filters))

        possible_answer_rates = question.answer_rates(filters: filters)

        question.possible_answers.sort_by_position.each_with_index do |possible_answer, possible_answer_index|
          # bar chart
          possible_answer_data = question_bar_chart_data[:possibleAnswers][possible_answer_index]

          expect(possible_answer_data[:answerCount]).to eq(possible_answer.answers_count(filters: filters))
          expect(possible_answer_data[:answerRate]).to eq((possible_answer_rates[possible_answer_index][:answer_rate] * 100).to_f.round)

          answers_by_day = Answer.filtered_answers(possible_answer.answers, filters: filters).
                           group("DATE(answers.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'GMT')").count

          expect(question_trend_chart_data[:seriesData][possible_answer_index][:data].map(&:last)).to eq(answers_by_day.values)
        end
      end
    end

    def expect_custom_content_params(custom_content_params, filters)
      question_params = custom_content_params[:question]
      expect(question_params[:id]).to eq @custom_content_question.id
      expect(question_params[:type]).to eq @custom_content_question.question_type
      expect(question_params[:content]).to eq @custom_content_question.content

      entire_link_click_count = @custom_content_question.custom_content_link_click_count(filters: filters)
      expect(custom_content_params[:entireLinkClickCount]).to eq entire_link_click_count

      @custom_content_question.custom_content_links.each_with_index do |link, index|
        expected_click_rate = entire_link_click_count.zero? ? 0 : (link.click_count(filters: filters) * 100 / entire_link_click_count).round
        link_params = custom_content_params[:links][index]

        expect(link_params[:id]).to eq link.id
        expect(link_params[:text]).to eq link.link_text
        expect(link_params[:url]).to eq link.link_url
        expect(link_params[:clickCount]).to eq link.click_count(filters: filters)
        expect(link_params[:clickRate]).to eq expected_click_rate
        expect(link_params[:color]).not_to be_nil
        expect(link_params[:colorUpdateUrl]).to eq update_color_custom_content_link_path(link.id)
      end
    end

    def make_answer(answer_extras: {}, submission_extras: {})
      possible_answer = @question.possible_answers.sort_by_position.first
      submission = create(:submission, survey_id: @survey.id, **submission_extras)
      create(:answer, question_id: @question.id, submission_id: submission.id, possible_answer_id: possible_answer.id, **answer_extras)

      possible_answer = @question.possible_answers.sort_by_position.last
      submission = create(:submission, survey_id: @survey.id, **submission_extras)
      create(:answer, question_id: @question.id, submission_id: submission.id, possible_answer_id: possible_answer.id, **answer_extras)
    end

    def make_click(submission_extras: {}, click_extras: {})
      submission = create(:submission, **submission_extras)
      create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, **click_extras)
      create(:custom_content_link_click, custom_content_link: @random_custom_content_link, submission: submission, **click_extras)
    end

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        it_filters_the_results(filters)
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_answer and make_click and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_answer(answer_extras: { created_at: attribute_value })
          make_click(click_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_answer(submission_extras: { filter_attribute => attribute_value })
          make_click(submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(@survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end
    end

    describe "with a market (survey_id) filter applied" do
      before do
        @survey.localize!

        @survey_locale_group = @survey.survey_locale_group

        @duplicate_survey1 = @survey.duplicate
        @duplicate_survey1.save
        @duplicate_survey1.add_to_localization_group(@survey_locale_group.id, "en-ca")

        @duplicate_survey2 = @survey.duplicate
        @duplicate_survey2.save
        @duplicate_survey2.add_to_localization_group(@survey_locale_group.id, "fr-ca")

        make_answer = lambda do |survey|
          submission = create(:submission, survey_id: survey.id)
          question = survey.questions.first
          possible_answer = question.possible_answers.sort_by_position.first
          create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: possible_answer.id)
        end

        submission = create(:submission, survey_id: @survey.id)
        make_answer.call(@survey)

        submission = create(:submission, survey_id: @duplicate_survey1.id)
        make_answer.call(@duplicate_survey1)
        make_answer.call(@duplicate_survey1)

        submission = create(:submission, survey_id: @duplicate_survey2.id)
        make_answer.call(@duplicate_survey2)
        make_answer.call(@duplicate_survey2)
        make_answer.call(@duplicate_survey2)
      end

      it "returns results filtered on market (survey_id)" do
        presenter = described_class.new(@survey, survey_locale_group: @survey_locale_group,
                                        filters: { market_ids: [@duplicate_survey1.id]}, current_user: @current_user)

        # question box
        question_data = presenter.report_component_params[:data][0]
        expect(question_data[:responseCount]).to eq(2) # one for each answer

        # bar chart
        possible_answer_data = question_data[:possibleAnswers][0]
        expect(possible_answer_data[:answerCount]).to eq(2) # one for each answer
        expect(possible_answer_data[:answerRate]).to eq(100) # all submissions had an answer

        possible_answer_data = question_data[:possibleAnswers][1]
        expect(possible_answer_data[:answerCount]).to eq(0) # one for each answer
        expect(possible_answer_data[:answerRate]).to eq(0) # no submissions had an answer

        # trend chart
        question_data = presenter.trend_report_params[:questions][@survey.questions.first.id]
        # data for first possible answer for @question
        expect(question_data[:seriesData][0][:data].map(&:last)).to eq([2]) # two responses on one day
        expect(question_data[:seriesData][1][:data].map(&:last)).to eq([]) # no responses on one day
        expect(question_data[:numResponses]).to eq(2)
      end

      it "returns results filtered on more than one market (survey_id) using OR logic" do
        presenter = described_class.new(@survey, survey_locale_group: @survey_locale_group,
                                        filters: { market_ids: [@duplicate_survey1.id, @duplicate_survey2.id]}, current_user: @current_user)

        # question box
        question_data = presenter.report_component_params[:data][0]
        expect(question_data[:responseCount]).to eq(5) # one for each answer

        # bar chart
        possible_answer_data = question_data[:possibleAnswers][0]
        expect(possible_answer_data[:answerCount]).to eq(5) # one for each answer
        expect(possible_answer_data[:answerRate]).to eq(100) # all submissions had an answer

        possible_answer_data = question_data[:possibleAnswers][1]
        expect(possible_answer_data[:answerCount]).to eq(0) # one for each answer
        expect(possible_answer_data[:answerRate]).to eq(0) # all submissions had an answer

        # trend chart
        question_data = presenter.trend_report_params[:questions][@survey.questions.first.id]
        # data for first possible answer for @question
        expect(question_data[:seriesData][0][:data].map(&:last)).to eq([5]) # five responses on one day
        expect(question_data[:seriesData][1][:data].map(&:last)).to eq([]) # no responses on one day
        expect(question_data[:numResponses]).to eq(5)
      end
    end
  end

  describe "available_markets" do
    it "returns a list of available markets" do
      survey = create(:localized_survey, name: "Survey B")

      survey_locale_group = survey.survey_locale_group
      duplicate_survey = survey.duplicate
      duplicate_survey.name = "Survey A"
      duplicate_survey.save
      duplicate_survey.add_to_localization_group(survey_locale_group.id, "en-ca")

      presenter = described_class.new(survey, survey_locale_group: survey_locale_group, current_user: create(:user, account: survey.account))

      expect(presenter.available_markets).to contain_exactly({id: duplicate_survey.id, label: duplicate_survey.name}, {id: survey.id, label: survey.name})
    end

    it "returns nil for a non-localized survey" do
      survey = create(:survey)

      presenter = described_class.new(survey, survey_locale_group: nil, current_user: create(:user, account: survey.account))

      expect(presenter.available_markets).to be_nil
    end
  end

  describe 'report_component_params' do
    before do
      @survey = create(:survey)
      @current_user = create(:user, account: @survey.account)

      question = @survey.questions.first

      3.times do |_|
        submission = create(:submission, survey_id: @survey.id)
        create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.first.id)
      end

      submission2 = create(:submission, survey_id: @survey.id)
      create(:answer, question_id: question.id, submission_id: submission2.id, possible_answer_id: question.possible_answers.first.id,
             created_at: 1.week.ago)

      submission3 = create(:submission, survey_id: @survey.id)
      create(:answer, question_id: question.id, submission_id: submission3.id, possible_answer_id: question.possible_answers.first.id,
             created_at: 2.weeks.ago)

      submission4 = create(:submission, survey_id: @survey.id)
      create(:answer, question_id: question.id, submission_id: submission4.id,
             possible_answer_id: question.possible_answers.last.id)

      freeze_time
    end

    after do
      unfreeze_time
    end

    def verify_question_data(question_data, question)
      expect(question_data.keys).to match_array(%i(id type content nextQuestionId))
      expect(question_data[:id]).to eq(question.id)
      expect(question_data[:type]).to eq(question.question_type)
      expect(question_data[:content]).to eq(question.content)
      expect(question_data[:nextQuestionId]).to eq(question.next_question_id)
    end

    def verify_possible_answer_data(possible_answer_data, answer_rate)
      expect(possible_answer_data.keys).to match_array(%i(id content answerRate nextQuestionId answerCount color colorUpdateUrl))

      possible_answer_record = localized ? answer_rate[:possible_answer].possible_answer_locale_group : answer_rate[:possible_answer]
      expect(possible_answer_data[:id]).to eq(possible_answer_record.id)

      expect(possible_answer_data[:content]).to eq(possible_answer_record.try(:content) || possible_answer_record.try(:name))

      expect(possible_answer_data[:answerRate]).to eq((answer_rate[:answer_rate] * 100).to_f.round)
      expect(possible_answer_data[:nextQuestionId]).to eq(answer_rate[:possible_answer].next_question_id)
      expect(possible_answer_data[:answerCount]).to eq(answer_rate[:answers_count])
      expect(possible_answer_data[:color].present?).to be(true)

      color_update_url = if localized
        update_color_possible_answer_locale_group_path(answer_rate[:possible_answer].possible_answer_locale_group_id)
      else
        update_color_possible_answer_path(answer_rate[:possible_answer].id)
      end

      expect(possible_answer_data[:colorUpdateUrl]).to eq(color_update_url)
    end

    def verify_report_component_params(report_component_params, survey, date_range = nil)
      filters = date_range ? { date_range: date_range } : {}

      expected_keys = %i(data numDaysActive filteringUrl trendParams reportDataUrl reportSummariesUrl includeAIAnalysis)
      expect(report_component_params.keys).to match_array(expected_keys)

      expect(report_component_params[:numDaysActive]).to eq(survey.active_days)
      expect(report_component_params[:filteringUrl]).to eq(ajax_report_survey_path(survey.id))
      expect(report_component_params[:includeAIAnalysis]).to eq(survey.account.ai_summaries_enabled)

      expect(report_component_params[:data].count).to eq(survey.questions.count)

      report_component_params[:data].each_with_index do |datum, question_index|
        question = survey.questions[question_index]

        expect(datum.keys).to match_array(%i(responseCount possibleAnswers question ungroupedResponseCount))

        expect(datum[:responseCount]).to eq(question.answers_count(:group_submission_id, filters: filters))
        expect(datum[:ungroupedResponseCount]).to eq(question.answers_count(filters: filters))

        expect(datum[:possibleAnswers].count).to eq(question.possible_answers.count)
        answer_rates = question.answer_rates(filters: filters).to_a

        datum[:possibleAnswers].each_with_index do |possible_answer_data, possible_answer_index|
          verify_possible_answer_data(possible_answer_data, answer_rates[possible_answer_index])
        end

        verify_question_data(datum[:question], question)
      end
    end

    it 'returns expected params in the simplest case' do
      presenter = described_class.new(@survey, survey_locale_group: nil, current_user: @current_user)
      report_component_params = presenter.report_component_params

      expect(report_component_params[:trendParams]).to eq(presenter.trend_report_params)
      expect(report_component_params[:reportDataUrl]).to eq(background_report_metrics_survey_path(@survey.id))
      expect(report_component_params[:reportSummariesUrl]).to eq(background_report_stats_survey_path(@survey.id))

      verify_report_component_params(report_component_params, @survey)
    end

    it 'returns expected params for an arbitrary date range' do
      date_range = (1.week.ago..Time.current)

      presenter = described_class.new(@survey, survey_locale_group: nil, filters: { date_range: date_range }, current_user: @current_user)
      report_component_params = presenter.report_component_params

      expect(report_component_params[:trendParams]).to eq(presenter.trend_report_params)

      expect(report_component_params[:reportDataUrl]).to eq(
        background_report_metrics_survey_path(@survey.id, date_range: date_range)
      )
      expect(report_component_params[:reportSummariesUrl]).to eq(
        background_report_stats_survey_path(@survey.id, date_range: date_range)
      )

      verify_report_component_params(report_component_params, @survey, date_range)
    end

    describe 'localized' do
      let(:localized) { true }

      it 'returns expected params in the simplest case' do
        survey = create(:localized_survey)

        survey_locale_group = survey.survey_locale_group

        presenter = described_class.new(survey, survey_locale_group: survey_locale_group, current_user: create(:user, account: survey.account))
        report_component_params = presenter.report_component_params

        expect(report_component_params[:trendParams]).to eq(presenter.trend_report_params)
        expect(report_component_params[:reportDataUrl]).to eq(localization_report_metrics_path(survey_locale_group.id))
        expect(report_component_params[:reportSummariesUrl]).to eq(localization_report_stats_path(survey_locale_group.id))

        verify_report_component_params(report_component_params, survey)
      end
    end
  end

  describe 'trend chart parameters' do
    describe "possible answer colours" do
      before do
        @survey = create(:survey_without_question)
        @question = create(:question_without_possible_answers, survey: @survey)
        @survey.reload
        @current_user = create(:user, account: @survey.account)
      end

      include_examples "trend report colors"
    end

    describe "possible answer locale group colours foo" do
      before do
        @survey = create(:survey_without_question)
        @question = create(:question_without_possible_answers, survey: @survey)
        @survey.reload
        @survey.localize!
        @question.reload
        @current_user = create(:user, account: @survey.account)
      end

      include_examples "trend report colors"
    end

    def verify_trend_report_params(trend_report_params, questions, survey, date_range = nil)
      filters = date_range ? { date_range: date_range } : {}
      expect(trend_report_params).not_to be_nil
      expect(trend_report_params.keys).to match_array(%i(questions timestamp updateUrl))

      expect(trend_report_params[:timestamp]).to be_within(2000).of(Time.current.to_i * 1000)
      expect(trend_report_params[:updateUrl]).to eq trend_report_data_survey_path(survey.id)

      question_params = trend_report_params[:questions]
      expect(question_params.keys).to match_array(survey.questions.pluck(:id))

      questions.each do |question|
        question_record = localized ? question.question_locale_group : question

        question_data = question_params[question.id]

        expect(question_data).not_to be_nil
        expect(question_data.keys).to match_array(%i(seriesData title numResponses chartId))

        expect(question_data[:chartId]).to eq(question_record.id)
        expect(question_data[:title]).to eq(question.content)

        expect(question_data[:numResponses]).to eq(question_record.answers_count(filters: filters))

        data_series = question_data[:seriesData]
        expect(data_series).not_to be_nil
        expect(data_series.count).to eq(question.possible_answers.count)

        verify_data_series(data_series, question, date_range)
      end
    end

    def verify_data_series(data_series, question, date_range)
      data_series.each do |data|
        expect(data.keys).to match_array(%i(id name data color))

        possible_answer_content = localized ? PossibleAnswerLocaleGroup.find(data[:id]).name : question.possible_answers.find_by(id: data[:id]).content

        expect(data[:name]).to eq(possible_answer_content)
        expect(described_class::COLOR_PALETTE.include?(data[:color])).to be(true)

        possible_answer_ids = localized ? PossibleAnswerLocaleGroup.find(data[:id]).possible_answers.pluck(:id) : data[:id]
        answer_scope = Answer.where(possible_answer_id: possible_answer_ids)
        answer_scope = answer_scope.where(created_at: date_range) if date_range

        # number of days on which there was at least one answer
        expect(data[:data].count).to eq(answer_scope.map { |answer| answer.created_at.to_date }.uniq.count)
        expect(data[:data].map(&:first)).to eq(data[:data].map(&:first).sort)

        data[:data].each do |datum|
          expect(datum.count).to eq(2)

          date = Time.zone.at(datum[0] / 1000)

          expect(Answer.where(created_at: (date.beginning_of_day..date.end_of_day)).exists?).to be(true)
          expect(datum[1]).to eq(answer_scope.where(created_at: date.beginning_of_day..date.end_of_day).count)
        end
      end
    end

    describe 'non-localized' do
      before do
        @survey = create(:survey)
        @current_user = create(:user, account: @survey.account)

        @question = @survey.questions.first

        3.times do |_|
          submission = create(:submission, survey_id: @survey.id)
          create(:answer, question_id: @question.id, submission_id: submission.id, possible_answer_id: @question.possible_answers.first.id,
                 created_at: DateTime.parse("2021-01-13 22:00"))
        end

        submission2 = create(:submission, survey_id: @survey.id)
        create(:answer, question_id: @question.id, submission_id: submission2.id, possible_answer_id: @question.possible_answers.first.id,
               created_at: DateTime.parse("2021-01-06 10:00"))

        submission3 = create(:submission, survey_id: @survey.id)
        create(:answer, question_id: @question.id, submission_id: submission3.id, possible_answer_id: @question.possible_answers.first.id,
               created_at: DateTime.parse("2021-01-05 23:59"))

        submission4 = create(:submission, survey_id: @survey.id)
        create(:answer, question_id: @question.id, submission_id: submission4.id,
               possible_answer_id: @question.possible_answers.last.id, created_at: DateTime.parse("2021-01-13 22:00"))
      end

      it 'returns accurate trend chart data in the simplest case' do
        presenter = described_class.new(@survey, survey_locale_group: nil, current_user: @current_user)
        trend_report_params = presenter.trend_report_params

        verify_trend_report_params(trend_report_params, @survey.questions, @survey)
      end

      it 'returns accurate trend chart data over an arbitrary date range' do
        start_time = DateTime.parse("2021-01-06").beginning_of_day
        end_time = DateTime.parse("2021-01-13").end_of_day
        date_range = start_time..end_time

        presenter = described_class.new(@survey, survey_locale_group: nil, filters: {date_range: date_range}, current_user: @current_user)
        trend_report_params = presenter.trend_report_params

        verify_trend_report_params(trend_report_params, @survey.questions, @survey, date_range)

        expect(trend_report_params[:questions][@question.id][:seriesData].first[:data].count).to eq(2)
      end
    end

    describe 'localized' do
      let(:localized) { true }

      it 'returns accurate localization trend chart data in the simplest case' do
        survey = create(:localized_survey)

        survey_locale_group = survey.survey_locale_group

        question_with_answers = survey_locale_group.base_survey.questions.first
        question = question_with_answers
        current_user = create(:user, account: survey.account)

        3.times do |_|
          submission = create(:submission, survey_id: survey.id)
          create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.first.id)
        end

        submission2 = create(:submission, survey_id: survey.id)
        create(:answer, question_id: question.id, submission_id: submission2.id, possible_answer_id: question.possible_answers.first.id,
               created_at: 1.week.ago)

        submission3 = create(:submission, survey_id: survey.id)
        create(:answer, question_id: question.id, submission_id: submission3.id, possible_answer_id: question.possible_answers.first.id,
               created_at: 2.weeks.ago)

        submission4 = create(:submission, survey_id: survey.id)
        create(:answer, question_id: question.id, submission_id: submission4.id,
               possible_answer_id: question.possible_answers.last.id)

        presenter = described_class.new(survey, survey_locale_group: survey_locale_group, current_user: current_user)
        trend_report_params = presenter.trend_report_params

        verify_trend_report_params(trend_report_params, survey.questions, survey)
      end

      it 'returns trend chart data for the the provided survey, not the base survey' do
        survey = create(:localized_survey)

        survey_locale_group = survey.survey_locale_group
        duplicate_survey = survey.duplicate
        duplicate_survey.save
        duplicate_survey.add_to_localization_group(survey_locale_group.id, "en-ca")

        question_with_answers = duplicate_survey.questions.first
        question = question_with_answers
        current_user = create(:user, account: survey.account)

        3.times do |_|
          submission = create(:submission, survey_id: duplicate_survey.id)
          create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.first.id)
        end

        submission2 = create(:submission, survey_id: duplicate_survey.id)
        create(:answer, question_id: question.id, submission_id: submission2.id, possible_answer_id: question.possible_answers.first.id,
               created_at: 1.week.ago)

        submission3 = create(:submission, survey_id: duplicate_survey.id)
        create(:answer, question_id: question.id, submission_id: submission3.id, possible_answer_id: question.possible_answers.first.id,
               created_at: 2.weeks.ago)

        submission4 = create(:submission, survey_id: duplicate_survey.id)
        create(:answer, question_id: question.id, submission_id: submission4.id,
               possible_answer_id: question.possible_answers.last.id)

        presenter = described_class.new(duplicate_survey, survey_locale_group: survey_locale_group, current_user: current_user)
        trend_report_params = presenter.trend_report_params

        verify_trend_report_params(trend_report_params, duplicate_survey.questions, duplicate_survey)
      end
    end
  end

  describe "skipping custom content question" do
    subject { presenter.report_component_params[:data].pluck(:question).pluck(:id) }

    let(:survey) { create(:survey, account: account) }
    let!(:custom_content_question) { create(:custom_content_question, survey: survey) }
    let(:presenter) { described_class.new(survey, current_user: create(:user, account: account)) }

    context 'when custom content link click is disabled' do
      let(:account) { create(:account, custom_content_link_click_enabled: false) }

      it { is_expected.not_to include custom_content_question.id }
    end

    context 'when custom content link click is enabled' do
      let(:account) { create(:account, custom_content_link_click_enabled: true) }

      context 'when no custom content link exists' do
        it { is_expected.not_to include custom_content_question.id }
      end

      context 'when no custom content link is active' do
        before do
          create(:custom_content_link, custom_content_question: custom_content_question, archived_at: Time.current)
        end

        it { is_expected.not_to include custom_content_question.id }
      end

      context 'when a custom content link exists' do
        before do
          create(:custom_content_link, custom_content_question: custom_content_question)
        end

        it { is_expected.to include custom_content_question.id }
      end
    end
  end

  describe "scheduled_report_links" do
    let(:account) { create(:account) }
    let(:survey) { create(:survey, account: account) }
    let(:current_user) { create(:user, account: account) }
    let(:presenter) { described_class.new(survey, current_user: current_user) }
    let(:links) { presenter.scheduled_report_links }

    it "has the expected top-level structure" do
      expect(links.is_a?(Hash)).to be true
      expect(links.keys).to match_array(%w(edit index new))
    end

    it "has the expected 'new' structure" do
      expect(links["new"].keys).to match_array(%w(url label))
      expect(links["new"]["url"]).to eq new_scheduled_report_path
      expect(links["new"]["label"]).to eq "Schedule A Report"
    end

    it "has the expected 'index' structure" do
      expect(links["index"].keys).to match_array(%w(url label))
      expect(links["index"]["url"]).to eq scheduled_reports_path
      expect(links["index"]["label"]).to eq "See all scheduled reports"
    end

    context "when the survey is not localized" do
      before do
        # contains survey explicitly
        create(:scheduled_report_without_emails, account: survey.account, all_surveys: false, surveys: [survey])

        # contains survey implicitly
        create(:scheduled_report_without_emails, account: survey.account, all_surveys: true)

        scheduled_report_ids = []
        scheduled_report_ids += ScheduledReport.where(account_id: survey.account, all_surveys: true).pluck(:id)
        scheduled_report_ids += ScheduledReportSurvey.where(survey_id: survey.id).pluck(:scheduled_report_id)

        @scheduled_reports_for_survey = ScheduledReport.where(id: scheduled_report_ids).to_a
      end

      it "has the expected 'edit' structure" do
        it_returns_expected_edit_structure(@scheduled_reports_for_survey)
      end
    end

    context "when the survey is localized" do
      before do
        survey.localize!

        # contains survey implicitly via survey locale group
        scheduled_report = create(:scheduled_report, all_surveys: false, account: survey.account)
        scheduled_report.survey_locale_groups << survey.survey_locale_group
        scheduled_report.scheduled_report_survey_locale_groups.first.surveys << survey

        @scheduled_reports_for_survey = ScheduledReport.where(id: scheduled_report.id)
      end

      it "has the expected 'edit' structure" do
        it_returns_expected_edit_structure(@scheduled_reports_for_survey)
      end
    end

    def it_returns_expected_edit_structure(scheduled_reports_for_survey)
      expect(links["edit"].class).to eq(Array)
      expect(links["edit"].count).to eq(scheduled_reports_for_survey.count)

      links["edit"].each_with_index do |edit_link, i|
        scheduled_report = scheduled_reports_for_survey[i]

        expect(edit_link.keys).to match_array(%w(url label))
        expect(edit_link["url"]).to eq edit_scheduled_report_path(scheduled_report)
        expect(edit_link["label"]).to eq scheduled_report.name
      end
    end
  end
end
