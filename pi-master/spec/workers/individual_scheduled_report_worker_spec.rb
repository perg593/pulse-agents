# frozen_string_literal: true
require 'spec_helper'

include ReportHelper

describe IndividualScheduledReportWorker do
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    ScheduledReport.delete_all
    ScheduledReportEmail.delete_all
    ScheduledReportSurvey.delete_all
    Sidekiq::Worker.clear_all
    Sidekiq::Queue.new.clear

    @valid_start_date = Time.current.beginning_of_minute + 2.minutes
  end

  let(:zone) { 'GMT' }
  let(:timezone) { ActiveSupport::TimeZone[zone] }

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:second_udid) { '00000000-0000-4000-f000-000000000002' }
  let(:third_udid) { '00000000-0000-4000-f000-000000000003' }
  let(:udid4) { '00000000-0000-4000-f000-000000000004' }

  let(:device) { create(:device, udid: udid) }

  it 'returns results on success' do
    start_date = @valid_start_date
    scheduled_report = create(:scheduled_report_with_account, start_date: start_date)

    survey = scheduled_report.surveys.first
    device = create(:device, udid: udid)

    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 1,
                        created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 00:00:00'))

    create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
           created_at: submission.created_at)

    result = described_class.new.perform(scheduled_report.id)
    expect(result.present?).to be true
  end

  it 'is marked as no longer in progress if it returns early due to having no impressions' do
    start_date = @valid_start_date
    scheduled_report = create(:scheduled_report_with_account, start_date: start_date, in_progress: true)

    result = described_class.new.perform(scheduled_report.id)
    expect(result).to eq []

    scheduled_report.reload
    expect(scheduled_report.in_progress).to be(false)
  end

  it 'updates send_next_report_at even if there were no impressions' do
    start_date = @valid_start_date
    scheduled_report = create(:scheduled_report_with_account, start_date: start_date, in_progress: true, frequency: 1)

    result = described_class.new.perform(scheduled_report.id)
    expect(result).to eq []

    scheduled_report.reload
    expect(scheduled_report.send_next_report_at).to be_within(1.minute).of start_date + 1.week
  end

  it 'sets send_next_report_at to nil if its end_date is in the past' do
    start_date = @valid_start_date
    end_date = Time.current + 1.hour

    scheduled_report = create(:scheduled_report_with_account, start_date: start_date, end_date: end_date)

    # create a submission and an answer so the worker doesn't early return
    survey = scheduled_report.surveys.first
    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 1,
                        created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 00:00:00'))
    create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
           created_at: submission.created_at)

    expect(scheduled_report.send_next_report_at).to be_within(1.second).of scheduled_report.start_date
    described_class.new.perform(scheduled_report.id)

    expect(scheduled_report.reload.send_next_report_at).to be_nil
  end

  describe "report results" do
    # Shamelessly copy+pasted from report_worker_spec.rb
    # TODO: https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1558
    describe "Custom content link click reporting" do
      let(:worker) { described_class.new }

      context "when custom content link click tracking is enabled" do
        context "when the survey has a custom content question with a link" do
          let(:account) { create(:account, custom_content_link_click_enabled: true) }
          let(:survey) { create(:survey_with_one_custom_question, account: account) }
          let(:report_job) { create(:scheduled_report_without_surveys, account: account, start_date: @valid_start_date, surveys: [survey]) }

          before do
            survey.reload
            @custom_content_link = create(:custom_content_link, custom_content_question: survey.questions.first)
          end

          describe "Aggregate results by day sheet" do
            before do
              @num_submissions_first_date = 3
              @submissions_on_first_date = []
              @num_submissions_first_date.times do
                @submissions_on_first_date << create(:submission, device_id: device.id,
                                                     survey_id: survey.id, udid: udid,
                                                     answers_count: 0, created_at: 1.days.ago)
              end

              @num_submissions_second_date = 2
              @submissions_on_second_date = []
              @num_submissions_second_date.times do
                @submissions_on_second_date << create(:submission, device_id: device.id,
                                                      survey_id: survey.id, udid: udid,
                                                      answers_count: 0, created_at: 2.days.ago)
              end

              @link_click_column_index = 4
              @header_row_index = 1
            end

            context "when there are no link clicks on a date with submissions" do
              before do
                @xlsx_package = worker.perform(report_job.id).first
              end

              it "adds 'Link Clicks' to the header" do
                @xlsx_package = worker.perform(report_job.id).first

                expected_header_row = ["Date", "Impressions", "Submissions", "Submission Rate", "Link Clicks"]
                expect(summary_by_day_worksheet(@xlsx_package)).to have_cells(expected_header_row).in_row(@header_row_index)
              end

              it "shows 0 link clicks for that date" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(0).at(@header_row_index + 1, @link_click_column_index)
              end

              it "shows a total of 0 link clicks overall" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(0).at(@header_row_index + 2, @link_click_column_index)
              end
            end

            context "when there are link clicks on a date with submissions" do
              before do
                @num_submissions_first_date.times do
                  submission = @submissions_on_first_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at)
                end

                @num_submissions_second_date.times do
                  submission = @submissions_on_second_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at)
                end

                @xlsx_package = worker.perform(report_job.id).first
              end

              it "adds 'Link Clicks' to the header" do
                @xlsx_package = worker.perform(report_job.id).first

                expected_header_row = ["Date", "Impressions", "Submissions", "Submission Rate", "Link Clicks"]
                expect(summary_by_day_worksheet(@xlsx_package)).to have_cells(expected_header_row).in_row(@header_row_index)
              end

              it "includes the total number of clicks for each date" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(@num_submissions_first_date).at(@header_row_index + 1, @link_click_column_index)
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(@num_submissions_second_date).at(@header_row_index + 2, @link_click_column_index)
              end

              it "includes the total number of clicks in the report date range" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(@num_submissions_first_date + @num_submissions_second_date).
                  at(@header_row_index + 3, @link_click_column_index)
              end
            end
          end

          describe "Custom Content Links sheet" do
            before do
              @header_row_index = 0
            end

            describe "Non-localized survey" do
              let(:non_localized_headers) { ["Date", "Time", "Survey Name", "Card Name", "Link Text", "Link URL", "SurveyID", "QuestionID", "LinkID", "SubmissionID", "Custom Data", "Pageview Count", "Visit Count", "IP Address", "Device Type", "DeviceUDID", "Client Key", "Completion URL", "View Name", "Event", "Device Data", "Previous Surveys", "OS", "Browser", "Browser Version", "Channel"] }

              before do
                num_submissions_first_date = 3
                @num_clicks_on_first_date = 3
                @submissions_on_first_date = []

                num_submissions_first_date.times do
                  @submissions_on_first_date << create(:submission, device_id: device.id,
                                                       survey_id: survey.id, udid: udid,
                                                       answers_count: 0, created_at: 1.days.ago)
                end
              end

              context "when there are link clicks in the report date range" do
                before do
                  @submissions_on_first_date.count.times do
                    submission = @submissions_on_first_date[0]
                    create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at)
                  end

                  @xlsx_package = worker.perform(report_job.id).first
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(non_localized_headers).in_row(@header_row_index)
                end

                it "has one line per click" do
                  expect(custom_content_links_sheet(@xlsx_package).rows.length).to eq(1 + @num_clicks_on_first_date) # header + num clicks
                end
              end

              context "when the link clicks have custom data" do
                before do
                  submission = @submissions_on_first_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at,
                         custom_data: {"foo" => "bar"})

                  @xlsx_package = worker.perform(report_job.id).first
                  @custom_data_column_index = 10
                end

                it "includes custom data from the custom_content_link_clicks record" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_value('{"foo": "bar"}').at(@header_row_index + 1, @custom_data_column_index)
                end
              end

              context "when the link clicks have a client key" do
                before do
                  submission = @submissions_on_first_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at,
                         client_key: {"foo" => "bar"})

                  @xlsx_package = worker.perform(report_job.id).first
                  @client_key_column_index = 16
                end

                it "includes the client key from the custom_content_link_clicks record" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_value('{"foo"=>"bar"}').at(@header_row_index + 1, @client_key_column_index)
                end
              end

              context "when there are no link clicks in the report date range" do
                before do
                  @xlsx_package = worker.perform(report_job.id).first
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(non_localized_headers).in_row(@header_row_index)
                end
              end
            end

            describe "localized survey" do
              let(:localized_headers) { ["Date", "Time", "Survey Group Name", "Survey Name", "Card Name", "Link Text", "Card Name Base", "Link URL", "Language Code", "Locale Code", "Survey Group ID", "Question Group ID", "SurveyID", "QuestionID", "LinkID", "SubmissionID", "Custom Data", "Pageview Count", "Visit Count", "IP Address", "Device Type", "DeviceUDID", "Client Key", "Completion URL", "View Name", "Event", "Device Data", "Previous Surveys", "OS", "Browser", "Browser Version", "Channel"] }
              let(:report_job) { create(:scheduled_report_without_surveys, account: account, start_date: @valid_start_date, survey_locale_groups: [survey.survey_locale_group], all_surveys: true) }

              before do
                survey.localize!
                survey.reload

                @num_submissions_first_date = 3
                @submissions_on_first_date = []
                @num_submissions_first_date.times do
                  @submissions_on_first_date << create(:submission, device_id: device.id,
                                                       survey_id: survey.id, udid: udid,
                                                       answers_count: 0, created_at: 1.days.ago)
                end
              end

              context "when there are link clicks in the report date range" do
                before do
                  @submissions_on_first_date.count.times do
                    submission = @submissions_on_first_date[0]
                    create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at)
                  end

                  @xlsx_package = worker.perform(report_job.id).first
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(localized_headers).in_row(@header_row_index)
                end

                it "has one line per click" do
                  expect(custom_content_links_sheet(@xlsx_package).rows.length).to eq(@header_row_index + 1 + @num_submissions_first_date) # header + num clicks
                end
              end

              context "when the link clicks have custom data" do
                before do
                  submission = @submissions_on_first_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at,
                         custom_data: {"foo" => "bar"})

                  @xlsx_package = worker.perform(report_job.id).first
                  @custom_data_column_index = 16
                end

                it "includes custom data from the custom_content_link_clicks record" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_value('{"foo": "bar"}').at(@header_row_index + 1, @custom_data_column_index)
                end
              end

              context "when the link clicks have a client key" do
                before do
                  submission = @submissions_on_first_date[0]
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: submission.created_at,
                         client_key: {"foo" => "bar"})

                  @xlsx_package = worker.perform(report_job.id).first
                  @client_key_column_index = 22
                end

                it "includes the client key from the custom_content_link_clicks record" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_value('{"foo"=>"bar"}').at(@header_row_index + 1, @client_key_column_index)
                end
              end

              context "when there are no link clicks in the report date range" do
                before do
                  @xlsx_package = worker.perform(report_job.id).first
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(localized_headers).in_row(0)
                end
              end
            end
          end
        end
      end
    end

    context "when only one survey" do
      let(:localized_report?) { false }
      let(:reportee_surveys) { [@survey] }

      before do
        start_date = @valid_start_date
        scheduled_report = create(:scheduled_report_with_account, start_date: start_date)

        @survey = scheduled_report.surveys.first
        @device = create(:device, udid: udid)
        ip_address = '192.168.0.1'

        create(:submission, device_id: @device.id, survey_id: @survey.id, udid: udid, ip_address: ip_address,
               answers_count: 0, created_at: ActiveSupport::TimeZone[zone].parse('2017-02-28  23:59:59'))

        submission1 = create(:submission, device_id: @device.id, survey_id: @survey.id, ip_address: ip_address, udid: second_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01 00:00:00'), viewed_at: timezone.parse('2017-03-01 00:00:00'))

        submission2 = create(:submission, device_id: @device.id, survey_id: @survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:58'), viewed_at: timezone.parse('2017-03-01  23:59:58'))

        submission3 = create(:submission, device_id: @device.id, survey_id: @survey.id, ip_address: ip_address, udid: udid4, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:57'), viewed_at: timezone.parse('2017-03-01  23:59:57'))

        create(:answer, question: @survey.questions.first, possible_answer: @survey.questions.first.possible_answers.first,
               submission: submission1, created_at: submission1.created_at)

        create(:answer, question: @survey.questions.first, possible_answer: @survey.questions.first.possible_answers.first,
               submission: submission2, created_at: submission2.created_at)

        create(:answer, question: @survey.questions.last, possible_answer: @survey.questions.last.possible_answers.first,
               submission: submission3, created_at: submission3.created_at)

        @result = described_class.new.perform(scheduled_report.id)

        @survey_result = @result.first
        @reportee = @survey
      end

      it 'returns an accurate xlsx file' do
        expect(@result.present?).to be true

        # one per survey with impressions
        # only one survey
        expect(@result.count).to eq 1

        # There should be a total of five worksheets
        expect(@survey_result.workbook.worksheets.count).to eq 5
      end

      it 'returns an accurate report overview sheet' do
        worksheet = report_overview_summary_by_day_worksheet(@survey_result)
        accurate_report_overview_sheet(@survey, worksheet)
      end

      it 'returns an accurate stats summary by day sheet' do
        worksheet = summary_by_day_worksheet(@survey_result)
        accurate_summary_by_day_sheet(@survey, worksheet)
      end

      it 'returns an accurate response summaries sheet' do
        worksheet = response_summaries_worksheet(@survey_result)
        accurate_response_summaries_sheet(@survey, worksheet)
      end

      it 'returns an accurate individual responses sheet' do
        worksheet = individual_responses_worksheet(@survey_result)
        accurate_individual_responses_sheet(@survey, worksheet)
      end

      it 'returns an accurate responses by device sheet' do
        worksheet = device_worksheet(@survey_result)
        accurate_responses_by_device_sheet(@survey, worksheet)
      end
    end

    context "when multiple surveys" do
      # "let" is not used because it caches
      def reportee_surveys
        [@survey]
      end

      let(:localized_report?) { false }

      before do
        start_date = @valid_start_date
        @scheduled_report = create(:scheduled_report_with_account, start_date: start_date, all_surveys: true)

        @survey1 = @scheduled_report.surveys.first
        device = create(:device, udid: udid)
        ip_address = '192.168.0.1'

        create(:submission, device_id: device.id, survey_id: @survey1.id, udid: udid, ip_address: ip_address,
               answers_count: 0, created_at: ActiveSupport::TimeZone[zone].parse('2017-02-28  23:59:59'))

        submission1 = create(:submission, device_id: device.id, survey_id: @survey1.id, ip_address: ip_address, udid: second_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01 00:00:00'), viewed_at: timezone.parse('2017-03-01 00:00:00'))

        submission2 = create(:submission, device_id: device.id, survey_id: @survey1.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:58'), viewed_at: timezone.parse('2017-03-01  23:59:58'))

        submission3 = create(:submission, device_id: device.id, survey_id: @survey1.id, ip_address: ip_address, udid: udid4, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:57'), viewed_at: timezone.parse('2017-03-01  23:59:57'))

        create(:answer, question: @survey1.questions.first, possible_answer: @survey1.questions.first.possible_answers.first,
               submission: submission1, created_at: submission1.created_at)

        create(:answer, question: @survey1.questions.first, possible_answer: @survey1.questions.first.possible_answers.first,
               submission: submission2, created_at: submission2.created_at)

        create(:answer, question: @survey1.questions.last, possible_answer: @survey1.questions.last.possible_answers.first,
               submission: submission3, created_at: submission3.created_at)

        @survey2 = create(:survey, account: @survey1.account, name: 'Survey 2')

        @result = described_class.new.perform(@scheduled_report.id)
        @surveys = [@survey1, @survey2]
      end

      it 'succeeds when only one survey has results' do
        expect(@result.present?).to be true
      end

      context "when each survey has results" do
        before do
          device = create(:device, udid: second_udid)
          ip_address = '192.168.0.2'

          create(:submission, device_id: device.id, survey_id: @survey2.id, udid: udid, ip_address: ip_address,
                 answers_count: 0, created_at: ActiveSupport::TimeZone[zone].parse('2018-02-28  23:59:59'))

          submission1 = create(:submission, device_id: device.id, survey_id: @survey2.id, ip_address: ip_address, udid: second_udid, answers_count: 1,
                               created_at: timezone.parse('2018-03-01 00:00:00'), viewed_at: timezone.parse('2018-03-01 00:00:00'))

          submission2 = create(:submission, device_id: device.id, survey_id: @survey2.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                               created_at: timezone.parse('2018-03-01  23:59:58'), viewed_at: timezone.parse('2018-03-01  23:59:58'))

          submission3 = create(:submission, device_id: device.id, survey_id: @survey2.id, ip_address: ip_address, udid: udid4, answers_count: 1,
                               created_at: timezone.parse('2018-03-01  23:59:57'), viewed_at: timezone.parse('2018-03-01  23:59:57'))

          create(:answer, question: @survey2.questions.first, possible_answer: @survey2.possible_answers.first,
                 submission: submission1, created_at: submission1.created_at)

          create(:answer, question: @survey2.questions.first, possible_answer: @survey2.possible_answers.first,
                 submission: submission2, created_at: submission2.created_at)

          create(:answer, question: @survey2.questions.first, possible_answer: @survey2.possible_answers.first,
                 submission: submission3, created_at: submission3.created_at)

          @result = described_class.new.perform(@scheduled_report.id)
        end

        it 'returns an accurate xlsx file' do
          expect(@result.present?).to be true

          # one per survey with impressions
          expect(@result.count).to eq 2

          # There should be a total of five worksheets
          expect(@result.first.workbook.worksheets.count).to eq 5
          expect(@result.second.workbook.worksheets.count).to eq 5
        end

        it 'returns an accurate report overview sheet' do
          @result.each_with_index do |result, i|
            @survey = @surveys[i]
            accurate_report_overview_sheet(@survey, report_overview_summary_by_day_worksheet(result))
          end
        end

        it 'returns an accurate stats summary by day sheet' do
          @result.each_with_index do |result, i|
            @survey = @surveys[i]
            accurate_summary_by_day_sheet(@survey, summary_by_day_worksheet(result))
          end
        end

        it 'returns an accurate response summaries sheet' do
          @result.each_with_index do |result, i|
            @survey = @surveys[i]
            accurate_response_summaries_sheet(@survey, response_summaries_worksheet(result))
          end
        end

        it 'returns an accurate individual responses sheet' do
          @result.each_with_index do |result, i|
            @survey = @surveys[i]
            accurate_individual_responses_sheet(@survey, individual_responses_worksheet(result))
          end
        end

        it 'returns an accurate responses by device sheet' do
          @result.each_with_index do |result, i|
            @survey = @surveys[i]
            accurate_responses_by_device_sheet(@survey, device_worksheet(result))
          end
        end
      end
    end

    context "when only one survey locale group" do
      let(:localized_report?) { true }
      let(:reportee_surveys) { @survey_locale_group.surveys }

      before do
        start_date = @valid_start_date
        @scheduled_report = create(:scheduled_report_with_survey_locale_group, start_date: start_date)

        @survey_locale_group = @scheduled_report.survey_locale_groups.first
        @base_survey = @survey_locale_group.base_survey
        @duplicate_survey = @base_survey.duplicate
        @duplicate_survey.add_to_localization_group(@survey_locale_group.id, "en_gb")
        @scheduled_report.scheduled_report_survey_locale_groups.first.surveys << @duplicate_survey

        # Differentiate the base and the duplicate to test question base and possible answer base
        @base_survey.questions.each { |q| q.update(content: "base_question_#{q.content}") }
        @base_survey.possible_answers.each { |pa| pa.update(content: "base_possible_answer_#{pa.content}") }

        # To test next_question_id and next_question_locale_group_id
        @base_survey.questions.first.next_question_id = @base_survey.questions.last.id
        @duplicate_survey.questions.first.possible_answers.first.next_question_id = @duplicate_survey.questions.last.id

        @survey_locale_group.surveys.each_with_index do |survey, index|
          5.times do |n|
            udid = "00000000-0000-4000-f000-00000000000#{n}"
            second_udid = "20000000-0000-4000-f000-00000000000#{n}"
            third_udid = "30000000-0000-4000-f000-00000000000#{n}"
            ip_address = "192.168.0.#{n}"
            created_at = timezone.parse('2010-10-10 10:10:10') + n.hours + index.minutes
            viewed_at = timezone.parse('2010-10-10 10:10:20') + n.hours + index.minutes

            create(:submission, device_id: device.id, survey_id: survey.id, udid: udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at)
            create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at + 1,
                   viewed_at: viewed_at + 1)

            submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                                created_at: created_at + 2, viewed_at: viewed_at + 2)
            create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
                   created_at: created_at)
          end
        end

        @xlsx_package = described_class.new.perform(@scheduled_report.id).first

        @reportee = @survey_locale_group
        @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups.first
      end

      it 'returns an xlsx package with all 5 sheets included' do
        expect(@xlsx_package.present?).to be true
        expect(@xlsx_package.workbook.worksheets.count).to eq 5 # "Survey metadata", "Summary stats by day", "Response summaries", "Individual rows", "Devices"
      end

      it 'returns an accurate report overview sheet' do
        worksheet = report_overview_summary_by_day_worksheet(@xlsx_package)
        accurate_report_overview_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate stats summary by day sheet' do
        worksheet = summary_by_day_worksheet(@xlsx_package)
        accurate_localized_summary_by_day_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate response summaries sheet' do
        worksheet = response_summaries_worksheet(@xlsx_package)
        accurate_localized_response_summaries_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate individual responses sheet' do
        worksheet = individual_responses_worksheet(@xlsx_package)
        accurate_localized_individual_responses_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate responses by device sheet' do
        worksheet = device_worksheet(@xlsx_package)
        accurate_localized_responses_by_device_sheet(@survey_locale_group, worksheet)
      end
    end

    context "when survey locale group is partially selected" do
      let(:localized_report?) { true }
      let(:reportee_surveys) { @partially_selected_report.surveys }

      before do
        start_date = @valid_start_date
        @scheduled_report = create(:scheduled_report_with_survey_locale_group, start_date: start_date)

        @survey_locale_group = @scheduled_report.survey_locale_groups.first
        @base_survey = @survey_locale_group.base_survey
        @duplicate_survey = @base_survey.duplicate
        @duplicate_survey.add_to_localization_group(@survey_locale_group.id, "en_gb")

        # Differentiate the base and the duplicate to test question base and possible answer base
        @base_survey.questions.each { |q| q.update(content: "base_question_#{q.content}") }
        @base_survey.possible_answers.each { |pa| pa.update(content: "base_possible_answer_#{pa.content}") }

        # To test next_question_id and next_question_locale_group_id
        @base_survey.questions.first.next_question_id = @base_survey.questions.last.id
        @duplicate_survey.questions.first.possible_answers.first.next_question_id = @duplicate_survey.questions.last.id

        @survey_locale_group.surveys.each do |survey|
          5.times do |n|
            udid = "00000000-0000-4000-f000-00000000000#{n}"
            second_udid = "20000000-0000-4000-f000-00000000000#{n}"
            third_udid = "30000000-0000-4000-f000-00000000000#{n}"
            ip_address = "192.168.0.#{n}"
            created_at = timezone.parse('2010-10-10 10:10:10') + n.minutes
            viewed_at = timezone.parse('2010-10-10 10:10:20') + n.minutes

            create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, ip_address: ip_address, answers_count: 0, created_at: created_at)
            create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, ip_address: ip_address, answers_count: 0, created_at: created_at,
                   viewed_at: viewed_at)

            submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                                 created_at: created_at, viewed_at: viewed_at)
            create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
                   created_at: created_at)
          end
        end

        @xlsx_package = described_class.new.perform(@scheduled_report.id).first

        @reportee = @survey_locale_group
        @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups.first
      end

      it 'returns an xlsx package with all 5 sheets included' do
        expect(@xlsx_package.present?).to be true
        expect(@xlsx_package.workbook.worksheets.count).to eq 5 # "Survey metadata", "Summary stats by day", "Response summaries", "Individual rows", "Devices"
      end

      it 'returns an accurate report overview sheet' do
        worksheet = report_overview_summary_by_day_worksheet(@xlsx_package)
        accurate_report_overview_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate stats summary by day sheet' do
        worksheet = summary_by_day_worksheet(@xlsx_package)
        accurate_localized_summary_by_day_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate response summaries sheet' do
        worksheet = response_summaries_worksheet(@xlsx_package)
        accurate_localized_response_summaries_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate individual responses sheet' do
        worksheet = individual_responses_worksheet(@xlsx_package)
        accurate_localized_individual_responses_sheet(@survey_locale_group, worksheet)
      end

      it 'returns an accurate responses by device sheet' do
        worksheet = device_worksheet(@xlsx_package)
        accurate_localized_responses_by_device_sheet(@survey_locale_group, worksheet)
      end
    end

    context 'when multiple survey groups' do
      # "let" is not used because it caches
      def reportee_surveys
        @survey_locale_group.surveys
      end

      let(:localized_report?) { true }

      before do
        start_date = @valid_start_date
        @scheduled_report = create(:scheduled_report_with_survey_locale_group, start_date: start_date)

        @survey_locale_group1 = @scheduled_report.survey_locale_groups.first
        @base_survey = @survey_locale_group1.base_survey
        @duplicate_survey = @base_survey.duplicate.tap(&:save)
        @duplicate_survey.add_to_localization_group(@survey_locale_group1.id, "en_gb")
        @scheduled_report.scheduled_report_survey_locale_groups.first.surveys << @duplicate_survey

        base_survey = create(:localized_survey, account: @base_survey.account)
        @survey_locale_group2 = base_survey.survey_locale_group
        dup_survey = base_survey.duplicate.tap(&:save)
        dup_survey.add_to_localization_group(@survey_locale_group2.id, 'test_lang_code')
        @scheduled_report.survey_locale_groups << @survey_locale_group2
        @scheduled_report.scheduled_report_survey_locale_groups.last.surveys << [base_survey, dup_survey]

        # Differentiate the base and the duplicate to test question base and possible answer base
        @base_survey.questions.each { |q| q.update(content: "base_question_#{q.content}") }
        @base_survey.possible_answers.each { |pa| pa.update(content: "base_possible_answer_#{pa.content}") }

        # To test next_question_id and next_question_locale_group_id
        @base_survey.questions.first.next_question_id = @base_survey.questions.last.id
        @duplicate_survey.questions.first.possible_answers.first.next_question_id = @duplicate_survey.questions.last.id

        @survey_locale_group1.surveys.each_with_index do |survey, index|
          5.times do |n|
            udid = "00000000-0000-4000-f000-00000000000#{n}"
            second_udid = "20000000-0000-4000-f000-00000000000#{n}"
            third_udid = "30000000-0000-4000-f000-00000000000#{n}"
            ip_address = "192.168.0.#{n}"
            created_at = timezone.parse('2010-10-10 10:10:10') + n.hours + index.minutes
            viewed_at = timezone.parse('2010-10-10 10:10:20') + n.hours + index.minutes

            create(:submission, device_id: device.id, survey_id: survey.id, udid: udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at)
            create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at + 1,
                   viewed_at: viewed_at + 1)

            submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                                created_at: created_at + 2, viewed_at: viewed_at + 2)
            create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
                   created_at: created_at)
          end
        end

        @survey_locale_group2.surveys.each_with_index do |survey, index|
          5.times do |n|
            udid = "01000000-0000-4000-f000-00000000000#{n}"
            second_udid = "21000000-0000-4000-f000-00000000000#{n}"
            third_udid = "310000000-0000-4000-f000-00000000000#{n}"
            ip_address = "192.168.1.#{n}"
            created_at = timezone.parse('2010-10-20 10:10:10') + n.hours + index.minutes
            viewed_at = timezone.parse('2010-10-20 10:10:20') + n.hours + index.minutes

            create(:submission, device_id: device.id, survey_id: survey.id, udid: udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at)
            create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at + 1,
                   viewed_at: viewed_at + 1)

            submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                                created_at: created_at + 2, viewed_at: viewed_at + 2)
            create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
                   created_at: created_at)
          end
        end

        @xlsx_packages = described_class.new.perform(@scheduled_report.id)
      end

      it 'returns an xlsx package with all 5 sheets included' do
        @xlsx_packages.each do |xlsx_package|
          expect(xlsx_package.present?).to be true
          expect(xlsx_package.workbook.worksheets.count).to eq 5 # "Survey metadata", "Summary stats by day", "Response summaries", "Individual rows", "Devices"
        end
      end

      it 'returns an accurate report overview sheet' do
        @xlsx_packages.each_with_index do |xlsx_package, index|
          @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups[index]
          @survey_locale_group = @partially_selected_report.survey_locale_group
          worksheet = report_overview_summary_by_day_worksheet(xlsx_package)
          accurate_report_overview_sheet(@survey_locale_group, worksheet)
        end
      end

      it 'returns an accurate stats summary by day sheet' do
        @xlsx_packages.each_with_index do |xlsx_package, index|
          @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups[index]
          @survey_locale_group = @partially_selected_report.survey_locale_group
          worksheet = summary_by_day_worksheet(xlsx_package)
          accurate_localized_summary_by_day_sheet(@survey_locale_group, worksheet)
        end
      end

      it 'returns an accurate response summaries sheet' do
        @xlsx_packages.each_with_index do |xlsx_package, index|
          @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups[index]
          @survey_locale_group = @partially_selected_report.survey_locale_group
          worksheet = response_summaries_worksheet(xlsx_package)
          accurate_localized_response_summaries_sheet(@survey_locale_group, worksheet)
        end
      end

      it 'returns an accurate individual responses sheet' do
        @xlsx_packages.each_with_index do |xlsx_package, index|
          @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups[index]
          @survey_locale_group = @partially_selected_report.survey_locale_group
          worksheet = individual_responses_worksheet(xlsx_package)
          accurate_localized_individual_responses_sheet(@survey_locale_group, worksheet)
        end
      end

      it 'returns an accurate responses by device sheet' do
        @xlsx_packages.each_with_index do |xlsx_package, index|
          @partially_selected_report = @scheduled_report.scheduled_report_survey_locale_groups[index]
          @survey_locale_group = @partially_selected_report.survey_locale_group
          worksheet = device_worksheet(xlsx_package)
          accurate_localized_responses_by_device_sheet(@survey_locale_group, worksheet)
        end
      end
    end

    context 'when scheduled_report.all_survey is true' do
      before do
        start_date = @valid_start_date
        @scheduled_report = create(:scheduled_report, start_date: start_date, all_surveys: true)
        account = @scheduled_report.account

        # "All Surveys" is all the survey groups and the stand-alone surveys in an account
        @survey = create(:survey, account: account)
        @base_survey = create(:localized_survey, account: account)
        @survey_locale_group = @base_survey.survey_locale_group
        @duplicate_survey = @base_survey.duplicate.tap(&:save)
        @duplicate_survey.add_to_localization_group(@survey_locale_group.id, "en_gb")

        # Differentiate the base and the duplicate to test question base and possible answer base
        @base_survey.questions.each { |q| q.update(content: "base_question_#{q.content}") }
        @base_survey.possible_answers.each { |pa| pa.update(content: "base_possible_answer_#{pa.content}") }

        # To test next_question_id and next_question_locale_group_id
        @base_survey.questions.first.next_question_id = @base_survey.questions.last.id
        @duplicate_survey.questions.first.possible_answers.first.next_question_id = @duplicate_survey.questions.last.id

        @survey_locale_group.surveys.each_with_index do |survey, index|
          5.times do |n|
            udid = "00000000-0000-4000-f000-00000000000#{n}"
            second_udid = "20000000-0000-4000-f000-00000000000#{n}"
            third_udid = "30000000-0000-4000-f000-00000000000#{n}"
            ip_address = "192.168.0.#{n}"
            created_at = timezone.parse('2010-10-10 10:10:10') + n.hours + index.minutes
            viewed_at = timezone.parse('2010-10-10 10:10:20') + n.hours + index.minutes

            create(:submission, device_id: device.id, survey_id: survey.id, udid: udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at)
            create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid,
                   ip_address: ip_address, answers_count: 0, created_at: created_at + 1,
                   viewed_at: viewed_at + 1)

            submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                                created_at: created_at + 2, viewed_at: viewed_at + 2)
            create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first, submission: submission,
                   created_at: created_at)
          end
        end

        5.times do |n|
          udid = "01000000-0000-4000-f000-00000000000#{n}"
          second_udid = "21000000-0000-4000-f000-00000000000#{n}"
          third_udid = "310000000-0000-4000-f000-00000000000#{n}"
          ip_address = "192.168.1.#{n}"
          created_at = timezone.parse('2010-10-20 10:10:10') + n.hours
          viewed_at = timezone.parse('2010-10-20 10:10:20') + n.hours

          create(:submission, device_id: device.id, survey_id: @survey.id, udid: udid,
                 ip_address: ip_address, answers_count: 0, created_at: created_at)
          create(:submission, device_id: device.id, survey_id: @survey.id, udid: second_udid,
                 ip_address: ip_address, answers_count: 0, created_at: created_at + 1,
                 viewed_at: viewed_at + 1)

          submission = create(:submission, device_id: device.id, survey_id: @survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                              created_at: created_at + 2, viewed_at: viewed_at + 2)
          create(:answer, question: @survey.questions.first, possible_answer: @survey.questions.first.possible_answers.first, submission: submission,
                 created_at: created_at)
        end

        xlsx_packages = described_class.new.perform(@scheduled_report.id)
        @locale_group_xlsx_package = xlsx_packages.first
        @survey_xlsx_package = xlsx_packages.last
      end

      describe 'survey report' do
        let(:localized_report?) { false }
        let(:reportee_surveys) { [@survey] }

        it 'returns an xlsx package with all 5 sheets included' do
          expect(@survey_xlsx_package.present?).to be true
          # "Survey metadata", "Summary stats by day", "Response summaries", "Individual rows", "Devices"
          expect(@survey_xlsx_package.workbook.worksheets.count).to eq 5
        end

        it 'returns an accurate report overview sheet' do
          worksheet = report_overview_summary_by_day_worksheet(@survey_xlsx_package)
          accurate_report_overview_sheet(@survey, worksheet)
        end

        it 'returns an accurate stats summary by day sheet' do
          worksheet = summary_by_day_worksheet(@survey_xlsx_package)
          accurate_summary_by_day_sheet(@survey, worksheet)
        end

        it 'returns an accurate response summaries sheet' do
          worksheet = response_summaries_worksheet(@survey_xlsx_package)
          accurate_response_summaries_sheet(@survey, worksheet)
        end

        it 'returns an accurate individual responses sheet' do
          worksheet = individual_responses_worksheet(@survey_xlsx_package)
          accurate_individual_responses_sheet(@survey, worksheet)
        end

        it 'returns an accurate responses by device sheet' do
          worksheet = device_worksheet(@survey_xlsx_package)
          accurate_responses_by_device_sheet(@survey, worksheet)
        end
      end

      describe 'localized report' do
        let(:localized_report?) { true }
        let(:reportee_surveys) { @survey_locale_group.surveys }

        it 'returns an xlsx package with all 5 sheets included' do
          expect(@locale_group_xlsx_package.present?).to be true
          # "Survey metadata", "Summary stats by day", "Response summaries", "Individual rows", "Devices"
          expect(@locale_group_xlsx_package.workbook.worksheets.count).to eq 5
        end

        it 'returns an accurate report overview sheet' do
          worksheet = report_overview_summary_by_day_worksheet(@locale_group_xlsx_package)
          accurate_report_overview_sheet(@survey_locale_group, worksheet)
        end

        it 'returns an accurate stats summary by day sheet' do
          worksheet = summary_by_day_worksheet(@locale_group_xlsx_package)
          accurate_localized_summary_by_day_sheet(@survey_locale_group, worksheet)
        end

        it 'returns an accurate response summaries sheet' do
          worksheet = response_summaries_worksheet(@locale_group_xlsx_package)
          accurate_localized_response_summaries_sheet(@survey_locale_group, worksheet)
        end

        it 'returns an accurate individual responses sheet' do
          worksheet = individual_responses_worksheet(@locale_group_xlsx_package)
          accurate_localized_individual_responses_sheet(@survey_locale_group, worksheet)
        end

        it 'returns an accurate responses by device sheet' do
          worksheet = device_worksheet(@locale_group_xlsx_package)
          accurate_localized_responses_by_device_sheet(@survey_locale_group, worksheet)
        end
      end
    end
  end

  describe 'Email' do
    describe 'Queueing' do
      let(:scheduled_report) { create(:scheduled_report, start_date: @valid_start_date) }

      context 'when there is no report generated' do
        context 'with send no results email marked as false' do
          it 'does not queue an email' do
            described_class.new.perform(scheduled_report.id)

            expect(ActionMailer::Base.deliveries.count).to eq 0
          end
        end

        context 'with send no results email marked as true' do
          before do
            scheduled_report.update send_no_results_email: true
          end

          it 'queues a no-results-email' do
            described_class.new.perform(scheduled_report.id)

            expect(ActionMailer::Base.deliveries.count).to eq 1
          end

          it 'the e-mail mentions that no results were found' do
            described_class.new.perform(scheduled_report.id)

            expect(ActionMailer::Base.deliveries.last.body.raw_source.scan("no impressions found").length).to eq 1
          end
        end
      end

      context 'when there is a single report generated' do
        it 'queues a single-report-email' do
          survey = scheduled_report.surveys.first
          submission = create(:submission, survey: survey, device: device, answers_count: 1)
          create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first)

          described_class.new.perform(scheduled_report.id)

          expect(ActionMailer::Base.deliveries.count).to eq 1
          expect(ActionMailer::Base.deliveries.last.subject).to include '[Pulse Insights] Report'
        end
      end

      context 'when there are multiple reports generated' do
        it 'queues a scheduled-report-email' do
          scheduled_report.surveys << create(:survey, account: scheduled_report.account)
          scheduled_report.surveys.each do |survey|
            submission = create(:submission, survey: survey, device: device, answers_count: 1)
            create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first)
          end

          described_class.new.perform(scheduled_report.id)

          expect(ActionMailer::Base.deliveries.count).to eq 1
          expect(ActionMailer::Base.deliveries.last.subject).to include 'Pulse Insights Scheduled Export:'
        end
      end
    end

    # Only when there is a single report. The email doesn't dislay stats when there are multiple reports
    describe 'Survey stats' do
      let(:account) { create(:account) }

      let(:parsed_email) { Nokogiri::HTML.parse(ActionMailer::Base.deliveries.last.html_part.body.to_s) }

      context 'when it is survey' do
        it "displays the survey's stats" do
          scheduled_report = create(:scheduled_report, account: account)
          survey = scheduled_report.surveys.first
          create_list(:submission, 10, survey: survey, device: device, answers_count: 1)                          # submission
          create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: Time.current) # viewed_impression
          create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: nil)          # impression

          described_class.new.perform(scheduled_report.id)

          expect(parsed_email.xpath("//div[@class='impressions']/div[@class='count']").first.text).to eq survey.blended_impressions_count.to_s
          expect(parsed_email.xpath("//div[@class='submissions']/div[@class='count']").first.text).to eq survey.submissions_count.to_s
          expect(parsed_email.xpath("//div[@class='submission_rate']/div[@class='count']").first.text).to eq survey.human_submission_rate
        end
      end

      context 'when it is survey group' do
        it 'displays stats that combine all surveys within the group' do
          scheduled_report = create(:scheduled_report_with_survey_locale_group, account: account)
          survey_locale_group = scheduled_report.survey_locale_groups.first
          base_survey = survey_locale_group.base_survey
          dup_survey = base_survey.duplicate.tap(&:save)
          dup_survey.add_to_localization_group(survey_locale_group.id, 'test_lang_code')

          survey_locale_group.surveys.each do |survey|
            create_list(:submission, 10, survey: survey, device: device, answers_count: 1)                          # submission
            create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: Time.current) # viewed_impression
            create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: nil)          # impression
          end

          described_class.new.perform(scheduled_report.id)

          surveys = scheduled_report.scheduled_report_survey_locale_groups.first.surveys # Partially selected(Not all surveys that belong to the group are used)
          blended_impressions_count = surveys.sum(&:blended_impressions_count)
          submissions_count = surveys.sum(&:submissions_count)
          submission_rate = (submissions_count.to_f / blended_impressions_count * 100).round
          expect(parsed_email.xpath("//div[@class='impressions']/div[@class='count']").first.text).to eq blended_impressions_count.to_s
          expect(parsed_email.xpath("//div[@class='submissions']/div[@class='count']").first.text).to eq submissions_count.to_s
          expect(parsed_email.xpath("//div[@class='submission_rate']/div[@class='count']").first.text).to eq "#{submission_rate}%"
        end
      end
    end
  end

  describe 'IP address inclusion' do
    before do
      @scheduled_report = create(:scheduled_report_with_account, start_date: @valid_start_date)

      @survey = @scheduled_report.surveys.first
      device = create(:device, udid: udid)

      submission1 = create(:submission, device_id: device.id, survey_id: @survey.id, ip_address: '192.168.0.1', answers_count: 1,
                           udid: second_udid, created_at: '2017-03-01'.to_datetime)

      submission2 = create(:submission, device_id: device.id, survey_id: @survey.id, ip_address: '192.168.0.2', answers_count: 1,
                           udid: third_udid, created_at: '2017-03-02'.to_datetime)

      create(:answer, question: @survey.questions.first, possible_answer: @survey.questions.first.possible_answers.first,
             submission: submission1, created_at: submission1.created_at)

      create(:answer, question: @survey.questions.first, possible_answer: @survey.questions.first.possible_answers.first,
             submission: submission2, created_at: submission2.created_at)
    end

    it 'is included by default' do
      result = described_class.new.perform(@scheduled_report.id)
      survey_result = result.first

      worksheet = individual_responses_worksheet(survey_result)
      first_row_index = 1

      @survey.answers.reorder(created_at: :desc).all.each_with_index do |answer, answer_index|
        expect(worksheet).to have_value(answer.submission.ip_address).at(first_row_index + answer_index, 13)
      end

      worksheet = device_worksheet(survey_result)
      first_row_index = 2

      @survey.submissions.order(created_at: :asc).group_by(&:device_id).each_with_index do |submissions_by_device_id, index|
        submission = submissions_by_device_id.last.last
        expect(worksheet).to have_value(submission.ip_address).at(first_row_index + index, 11)
      end
    end

    it 'is excluded if the account wants it excluded' do
      @survey.account.update(ip_storage_policy: :store_none)

      result = described_class.new.perform(@scheduled_report.id)
      survey_result = result.first

      worksheet = individual_responses_worksheet(survey_result)
      first_row_index = 1

      @survey.answers.count.times do |row_index|
        expect(worksheet).to have_value(nil).at(first_row_index + row_index, 12)
      end

      worksheet = device_worksheet(survey_result)
      first_row_index = 2

      @survey.submissions.group_by(&:device_id).count.times do |row_index|
        expect(worksheet).to have_value(nil).at(first_row_index + row_index, 10)
      end
    end
  end

  context 'when individual_rows does not exceed limit' do
    before do
      start_date = @valid_start_date
      @scheduled_report = create(:scheduled_report_with_account, start_date: start_date)

      @survey = @scheduled_report.surveys.first
      @survey.reload

      @question1 = @survey.questions.first
      @question2 = @survey.questions.last

      possible_answer1 = @survey.questions.first.possible_answers.first
      possible_answer2 = @survey.questions.last.possible_answers.first

      @device = create(:device, udid: udid)
      @device1 = create(:device, udid: second_udid)
      @device2 = create(:device, udid: third_udid)
      @device3 = create(:device, udid: udid4)

      submission = create(:submission, device_id: @device.id, survey_id: @survey.id,
                          udid: udid, answers_count: 0, created_at: ActiveSupport::TimeZone[zone].parse('2017-02-28 23:59:59'))
      submission1 = create(:submission, device_id: @device1.id, survey_id: @survey.id,
                           udid: second_udid, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 00:00:00'))
      submission2 = create(:submission, device_id: @device2.id, survey_id: @survey.id,
                           udid: third_udid, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 23:59:58'))
      submission3 = create(:submission, device_id: @device3.id, survey_id: @survey.id,
                           udid: udid4, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 23:59:57'))

      create(:answer, question: @question1, possible_answer: possible_answer1, submission: submission1, created_at: submission1.created_at)
      create(:answer, question: @question1, possible_answer: possible_answer1, submission: submission2, created_at: submission2.created_at)
      create(:answer, question: @question2, possible_answer: possible_answer2, submission: submission3, created_at: submission3.created_at)
    end

    it 'does not generate a csv file' do
      worker = described_class.new
      allow(worker).to receive(:individual_rows_exceeded?) { false }
      allow(worker).to receive(:individual_rows_filepath) { "tmp/individual_scheduled_report_worker_test.csv" }

      FileUtils.rm_f(worker.individual_rows_filepath)

      result = worker.perform(@scheduled_report.id)
      expect(result.present?).to be true
      expect(result.first.workbook.sheet_by_name('Individual rows')).not_to be_nil

      expect(File.exist?(worker.individual_rows_filepath)).to be false
    end
  end

  context 'when individual_rows exceeds limit' do
    before do
      start_date = @valid_start_date
      @scheduled_report = create(:scheduled_report_with_account, start_date: start_date)

      @survey = @scheduled_report.surveys.first
      @survey.reload

      @question1 = @survey.questions.first
      @question2 = @survey.questions.last

      possible_answer1 = @survey.questions.first.possible_answers.first
      possible_answer2 = @survey.questions.last.possible_answers.first

      @device = create(:device, udid: udid)
      @device1 = create(:device, udid: second_udid)
      @device2 = create(:device, udid: third_udid)
      @device3 = create(:device, udid: udid4)

      submission = create(:submission, device_id: @device.id, survey_id: @survey.id,
                          udid: udid, answers_count: 0, created_at: ActiveSupport::TimeZone[zone].parse('2017-02-28 23:59:59'))
      submission1 = create(:submission, device_id: @device1.id, survey_id: @survey.id,
                           udid: second_udid, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 00:00:00'))
      submission2 = create(:submission, device_id: @device2.id, survey_id: @survey.id,
                           udid: third_udid, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 23:59:58'))
      submission3 = create(:submission, device_id: @device3.id, survey_id: @survey.id,
                           udid: udid4, answers_count: 1, created_at: ActiveSupport::TimeZone[zone].parse('2017-03-01 23:59:57'))

      create(:answer, question: @question1, possible_answer: possible_answer1, submission: submission1, created_at: submission1.created_at)
      create(:answer, question: @question1, possible_answer: possible_answer1, submission: submission2, created_at: submission2.created_at)
      create(:answer, question: @question2, possible_answer: possible_answer2, submission: submission3, created_at: submission3.created_at)

      @worker = described_class.new
      allow(@worker).to receive(:individual_rows_exceeded?) { true }
      allow(@worker).to receive(:individual_rows_filepath) { "tmp/individual_scheduled_report_worker_test.csv" }
      allow(@worker).to receive(:attach_file_to_email?) { true }
      allow(@worker).to receive(:upload_csv_file) { "test.csv" }
      allow(@worker).to receive(:upload_xlsx_file) { "test.xlsx" }

      # don't have enough info to get the filepath because it's based on other state x_x
      # Maybe just wipe all.csv from tmp dir?
      FileUtils.rm_f(@worker.individual_rows_filepath)
    end

    it 'generates a csv file' do
      result = @worker.perform(@scheduled_report.id)
      expect(result.present?).to be true
      expect(result.first.workbook.sheet_by_name('Individual rows')).to be_nil

      rows = CSV.parse(File.read(@worker.individual_rows_filepath), headers: true)

      expect(rows[0]['Date']).to eq '03/01/2017'
      expect(rows[0]['Time']).to eq '23:59:58'
      expect(rows[0]['Question']).to eq @question1.content
      expect(rows[0]['SurveyID'].to_i).to eq @survey.id
      expect(rows[0]['DeviceUDID']).to eq @device2.udid

      expect(rows[1]['Date']).to eq '03/01/2017'
      expect(rows[1]['Time']).to eq '23:59:57'
      expect(rows[1]['Question']).to eq @question2.content
      expect(rows[1]['SurveyID'].to_i).to eq @survey.id
      expect(rows[1]['DeviceUDID']).to eq @device3.udid

      expect(rows[2]['Date']).to eq '03/01/2017'
      expect(rows[2]['Time']).to eq '00:00:00'
      expect(rows[2]['Question']).to eq @question1.content
      expect(rows[2]['SurveyID'].to_i).to eq @survey.id
      expect(rows[2]['DeviceUDID']).to eq @device1.udid
    end

    # TODO: Uncomment this once it passes CI consistently
    # it 'attaches the CSV to the report e-mail if small enough' do
    #   ActionMailer::Base.deliveries.clear
    #
    #   result = @worker.perform(@scheduled_report.id)
    #   expect(result.present?).to eq true
    #   expect(result.first.workbook.sheet_by_name('Individual rows')).to be nil
    #
    #   mail = ActionMailer::Base.deliveries.last
    #
    #   expect(mail.attachments.present?).to eq true
    #   expect(mail.attachments.count).to eq 2
    #   expect(mail.attachments.detect { |attachment| attachment.filename == 'individual_rows.csv' }).not_to be nil
    #
    #   # expect to find that CSV file URL in the e-mail
    #   expect(mail.html_part.encoded.scan(/\.csv/).length).to eq 1
    # end

    # it 'does not attach the CSV to the report e-mail if too big' do
    #   allow(@worker).to receive(:attach_file_to_email?) { true }
    #   allow(@worker).to receive(:attach_csv_file_to_email?) { false }
    #
    #   result = @worker.perform(@scheduled_report.id)
    #
    #   mail = ActionMailer::Base.deliveries.last
    #   expect(mail.attachments.count).to eq 1
    #   expect(mail.attachments.detect { |attachment| attachment.filename == 'individual_rows.csv' }).to be nil
    #
    #   # expect to find that CSV file URL in the e-mail
    #   expect(mail.html_part.encoded.scan(/\.csv/).length).to eq 1
    # end

    it 'does not attach any CSV files to the report e-mail if the report contains multiple surveys' do
      @scheduled_report.update(all_surveys: true)
      allow(@worker).to receive(:attach_file_to_email?) { true }
      allow(@worker).to receive(:attach_csv_file_to_email?) { true }

      new_survey = create(:survey, account: @survey.account, name: 'Survey 2')

      new_impression = Submission.last.dup
      new_impression.survey_id = new_survey.id
      new_impression.save

      new_answer = Answer.last.dup
      new_answer.submission_id = new_impression.id
      new_answer.save

      result = @worker.perform(@scheduled_report.id)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.attachments.present?).to be false
    end

    it 'includes links to the CSV files when the report contains multiple surveys' do
      @scheduled_report.update(all_surveys: true)

      new_survey = create(:survey, account: @survey.account, name: 'Survey 2')

      new_impression = Submission.last.dup
      new_impression.survey_id = new_survey.id
      new_impression.save

      new_answer = Answer.last.dup
      new_answer.submission_id = new_impression.id
      new_answer.save

      expect(@survey.submissions.count).not_to eq 0
      expect(new_survey.submissions.count).not_to eq 0

      old_num_deliveries = ActionMailer::Base.deliveries.count

      result = @worker.perform(@scheduled_report.id)
      expect(result.present?).to be true
      expect(ActionMailer::Base.deliveries.count).to eq(old_num_deliveries + 1)

      num_url_pairs_expected = @scheduled_report.account.surveys.count

      mail = ActionMailer::Base.deliveries.last
      expect(mail.multipart?).to be false

      # expect a pair of xlsx-csv urls for each survey in report
      expect(mail.body.raw_source.scan(/test.csv/).length).to eq num_url_pairs_expected
      expect(mail.body.raw_source.scan(/test.xlsx/).length).to eq num_url_pairs_expected
    end
  end

  it_behaves_like 'report worker with viewed impressions considered' do
    let(:report_object) { create(:scheduled_report) }
    let(:reportee) { report_object.surveys.first }
    let(:date_format) { "%m/%d/%Y" }
  end
end
