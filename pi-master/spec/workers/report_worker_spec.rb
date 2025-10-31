# frozen_string_literal: true
require 'spec_helper'

include ReportHelper

describe ReportWorker do
  let(:timezone) { ActiveSupport::TimeZone['GMT'] }
  let(:worker) { described_class.new }

  # TODO: Use narrower date ranges, customized to the individual test case
  let(:account) { create(:account, viewed_impressions_enabled_at: timezone.parse('2000-01-01')) }

  let(:user) { create(:user, account: account) }
  let(:current_user_email) { user.email }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:second_udid) { '00000000-0000-4000-f000-000000000002' }
  let(:third_udid) { '00000000-0000-4000-f000-000000000003' }
  let(:fourth_udid) { '00000000-0000-4000-f000-000000000004' }
  let(:device) { create(:device, udid: udid) }

  before do
    allow(worker).to receive(:upload_xlsx_file) { '' }
    allow(worker).to receive(:upload_csv_file) { '' }

    delete_report_files
  end

  def delete_report_files
    Dir.glob("tmp/*.csv").each { |filepath| File.delete(filepath) }
    Dir.glob("tmp/*.xlsx").each { |filepath| File.delete(filepath) }
  end

  describe "report results" do
    describe "Custom content link click reporting" do
      context "when custom content link click tracking is enabled" do
        context "when the survey has a custom content question with a link" do
          let(:survey) { create(:survey_with_one_custom_question, account: account) }
          let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }

          before do
            account.update(custom_content_link_click_enabled: true)

            survey.reload
            @custom_content_link = create(:custom_content_link, custom_content_question: survey.questions.first)
          end

          describe "Aggregate results by day sheet" do
            before do
              @link_click_column_index = 4
              @header_row_index = 1
            end

            it "adds 'Link Clicks' to the header" do
              @xlsx_package = worker.perform(report_job.id)

              expected_header_row = ["Date", "Impressions", "Submissions", "Submission Rate", "Link Clicks"]
              expect(summary_by_day_worksheet(@xlsx_package)).to have_cells(expected_header_row).in_row(@header_row_index)
            end

            context "when there are no link clicks on a date with submissions" do
              before do
                create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)
                @xlsx_package = worker.perform(report_job.id)
              end

              it "shows 0 link clicks for that date" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(0).at(@header_row_index + 1, @link_click_column_index)
              end

              it "shows a total of 0 link clicks overall" do
                expect(summary_by_day_worksheet(@xlsx_package)).to have_value(0).at(@header_row_index + 2, @link_click_column_index)
              end
            end

            context "when there are no active links" do
              before do
                submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)
                create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)

                @custom_content_link.archive!

                @xlsx_package = worker.perform(report_job.id)
              end

              it "doesn't include 'Link Clicks' in the header" do
                headers = summary_by_day_worksheet(@xlsx_package).rows[@header_row_index].cells.map(&:value)
                expect(headers).not_to include 'Link Clicks'
              end

              it "doesn't show click counts" do
                submission_stats_row = summary_by_day_worksheet(@xlsx_package).rows[@header_row_index + 2]
                expect(submission_stats_row.cells[@link_click_column_index]).to be_nil
              end
            end

            context "when there are link clicks on a date with submissions" do
              before do
                @num_submissions_first_date = 3
                @num_submissions_first_date.times do
                  submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)
                end

                @num_submissions_second_date = 2
                @num_submissions_second_date.times do
                  submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 2.days.ago)
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 2.day.ago)
                end

                @xlsx_package = worker.perform(report_job.id)
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

              context "when there are link clicks in the report date range" do
                before do
                  num_submissions_first_date = 3
                  @num_clicks_on_first_date = 3

                  num_submissions_first_date.times do
                    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)
                    create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)
                  end

                  @xlsx_package = worker.perform(report_job.id)
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(non_localized_headers).in_row(@header_row_index)
                end

                it "has one line per click" do
                  expect(custom_content_links_sheet(@xlsx_package).rows.length).to eq(@header_row_index + 1 + @num_clicks_on_first_date) # header + num clicks
                end
              end

              context "when there are no link clicks in the report date range" do
                before do
                  @xlsx_package = worker.perform(report_job.id)
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(non_localized_headers).in_row(@header_row_index)
                end
              end

              context "when there are no active links" do
                before do
                  submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)

                  @custom_content_link.archive!
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)

                  @xlsx_package = worker.perform(report_job.id)
                end

                it "skips the sheet generation" do
                  expect(custom_content_links_sheet(@xlsx_package)).to be_nil
                end
              end
            end

            describe "localized survey" do
              let(:localized_headers) { ["Date", "Time", "Survey Group Name", "Survey Name", "Card Name", "Link Text", "Card Name Base", "Link URL", "Language Code", "Locale Code", "Survey Group ID", "Question Group ID", "SurveyID", "QuestionID", "LinkID", "SubmissionID", "Custom Data", "Pageview Count", "Visit Count", "IP Address", "Device Type", "DeviceUDID", "Client Key", "Completion URL", "View Name", "Event", "Device Data", "Previous Surveys", "OS", "Browser", "Browser Version", "Channel"] }

              before do
                survey.localize!
              end

              context "when there are link clicks in the report date range" do
                before do
                  @num_submissions_first_date = 3
                  @num_clicks_on_first_date = 3
                  @num_submissions_first_date.times do
                    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)
                    create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)
                  end

                  @xlsx_package = worker.perform(report_job.id)
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(localized_headers).in_row(@header_row_index)
                end

                it "has one line per click" do
                  expect(custom_content_links_sheet(@xlsx_package).rows.length).to eq(1 + @num_clicks_on_first_date) # header + num clicks
                end
              end

              context "when there are no link clicks in the report date range" do
                before do
                  @xlsx_package = worker.perform(report_job.id)
                end

                it "has the expected headers" do
                  expect(custom_content_links_sheet(@xlsx_package)).to have_cells(localized_headers).in_row(@header_row_index)
                end
              end

              context "when there are no active links" do
                before do
                  submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: 1.days.ago)

                  @custom_content_link.archive!
                  create(:custom_content_link_click, custom_content_link: @custom_content_link, submission: submission, created_at: 1.days.ago)

                  @xlsx_package = worker.perform(report_job.id)
                end

                it "skips the sheet generation" do
                  expect(custom_content_links_sheet(@xlsx_package)).to be_nil
                end
              end
            end
          end
        end
      end
    end

    context 'when the survey is stand-alone' do
      let(:survey) { create(:survey, account: account) }
      let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }
      let(:reportee_surveys) { [survey] }
      let(:localized_report?) { false }

      before do
        ip_address = '192.168.0.1'

        create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, ip_address: ip_address,
               answers_count: 0, created_at: timezone.parse('2017-02-28  23:59:59'))

        first_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: second_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01 00:00:00'), viewed_at: timezone.parse('2017-03-01 00:00:00'))

        second_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:58'), viewed_at: timezone.parse('2017-03-01  23:59:58'))

        third_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: fourth_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:57'), viewed_at: timezone.parse('2017-03-01  23:59:57'))

        create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first,
               submission: first_submission, created_at: first_submission.created_at)

        create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first,
               submission: second_submission, created_at: second_submission.created_at)

        create(:answer, question: survey.questions.last, possible_answer: survey.questions.last.possible_answers.first,
               submission: third_submission, created_at: third_submission.created_at)

        @xlsx_package = worker.perform(report_job.id)
      end

      it_behaves_like "report worker output for non-localized survey"
    end

    context 'when the survey is localized' do
      let(:survey) { create(:localized_survey, account: account) }
      let(:survey_locale_group) { survey.survey_locale_group }
      let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }
      let(:reportee_surveys) { [survey] }
      let(:localized_report?) { true }

      before do
        ip_address = '192.168.0.1'

        create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, ip_address: ip_address,
               answers_count: 0, created_at: timezone.parse('2017-02-28  23:59:59'))

        first_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: second_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01 00:00:00'), viewed_at: timezone.parse('2017-03-01 00:00:00'))

        second_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: third_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:58'), viewed_at: timezone.parse('2017-03-01  23:59:58'))

        third_submission = create(:submission, device_id: device.id, survey_id: survey.id, ip_address: ip_address, udid: fourth_udid, answers_count: 1,
                             created_at: timezone.parse('2017-03-01  23:59:57'), viewed_at: timezone.parse('2017-03-01  23:59:57'))

        create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first,
               submission: first_submission, created_at: first_submission.created_at)

        create(:answer, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first,
               submission: second_submission, created_at: second_submission.created_at)

        create(:answer, question: survey.questions.last, possible_answer: survey.questions.last.possible_answers.first,
               submission: third_submission, created_at: third_submission.created_at)

        @xlsx_package = worker.perform(report_job.id)
      end

      it_behaves_like "report worker output for localized survey" do
        let(:reportee) { survey }
      end
    end

    context 'when survey group' do
      let(:base_survey) { create(:localized_survey, account: account) }
      let(:survey_locale_group) { base_survey.survey_locale_group }
      let(:report_job) { create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email) }
      let(:reportee_surveys) { survey_locale_group.surveys }
      let(:localized_report?) { true }

      before do
        duplicate_survey = base_survey.duplicate
        duplicate_survey.add_to_localization_group(survey_locale_group.id, "en_gb")

        # Differentiate the base and the duplicate to test question base and possible answer base
        base_survey.questions.each { |q| q.update(content: "base_question_#{q.content}") }
        base_survey.possible_answers.each { |pa| pa.update(content: "base_possible_answer_#{pa.content}") }

        # To test next_question_id and next_question_locale_group_id
        base_survey.questions.first.next_question_id = base_survey.questions.last.id
        duplicate_survey.questions.first.possible_answers.first.next_question_id = duplicate_survey.questions.last.id

        survey_locale_group.surveys.each_with_index do |survey, index|
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

        @xlsx_package = worker.perform(report_job.id)
      end

      it_behaves_like "report worker output for localized survey" do
        let(:reportee) { survey_locale_group }
      end
    end

    describe "Device filter" do
      context 'when the report is for a survey' do
        let(:survey) { create(:survey, account: account) }
        let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { [survey] }
        let(:localized_report?) { false }

        before do
          first_question = survey.reload.questions.first
          last_question = survey.questions.last
          first_question.update(next_question_id: last_question.id)

          create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, device_type: "desktop", created_at: 20.minutes.ago)
          first_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, answers_count: 1, created_at: 10.minutes.ago,
                               device_type: "desktop")
          second_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: third_udid, answers_count: 1, created_at: 5.minutes.ago,
                               device_type: "desktop")
          third_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: fourth_udid, answers_count: 1, created_at: 1.minutes.ago,
                               device_type: "mobile")

          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)

          target_devices = ["desktop"]
          @filters = { device_types: target_devices }
          report_job.update(filters: {device_filter: target_devices})
          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for non-localized survey"
      end

      context 'when the report is for a survey group' do
        let(:base_survey) { create(:localized_survey, account: account) }
        let(:survey_locale_group) { base_survey.survey_locale_group }
        let(:report_job) { create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { survey_locale_group.surveys }
        let(:localized_report?) { true }

        before do
          duplicated_survey = base_survey.duplicate.tap(&:save)
          first_question = base_survey.questions.reload.first
          last_question  = base_survey.questions.last
          duplicated_question = duplicated_survey.questions.reload.first
          first_question.update(next_question_id: last_question.id)

          udids = 5.times.map { |n| "00000000-0000-4000-f000-00000000000#{n}" }
          create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids.first, answers_count: 0, created_at: Time.current,
                 device_type: "desktop")

          first_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[1],
                               answers_count: 1, created_at: 10.minutes.ago, viewed_at: 10.minutes.ago, device_type: "desktop")
          second_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[2],
                               answers_count: 1, created_at: 5.minutes.ago, viewed_at: 5.minutes.ago, device_type: "desktop")
          third_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[3],
                               answers_count: 1, created_at: 1.minute.ago, viewed_at: 1.minute.ago, device_type: "desktop")
          submission4 = create(:submission, device_id: device.id, survey_id: duplicated_survey.id, udid: udids[4], answers_count: 1,
                               created_at: Time.current, device_type: "mobile")
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)
          create(:answer, question: duplicated_question, possible_answer: duplicated_question.possible_answers.first, submission: submission4,
                 created_at: submission4.created_at)

          target_devices = ["desktop"]
          report_job.update(filters: {device_filter: target_devices})
          @filters = { device_types: target_devices }

          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for localized survey" do
          let(:reportee) { survey_locale_group }
        end
      end
    end

    describe "Completion URL filter" do
      context 'when the report is for a survey' do
        let(:survey) { create(:survey, account: account) }
        let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { [survey] }
        let(:localized_report?) { false }

        before do
          first_question = survey.reload.questions.first
          last_question = survey.questions.last
          first_question.update(next_question_id: last_question.id)

          create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, url: "alpha", created_at: 20.minutes.ago)
          first_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, answers_count: 1, created_at: 10.minutes.ago,
                               url: "alpha")
          second_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: third_udid, answers_count: 1, created_at: 5.minutes.ago,
                               url: "alpha")
          third_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: fourth_udid, answers_count: 1, created_at: 1.minutes.ago,
                               url: "xyz")

          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)

          matcher = "contains"
          value = "a"
          cumulative = false

          completion_url_filters = [CompletionUrlFilter.new(matcher, value, cumulative: cumulative)]
          report_job.update(filters: {completion_urls: [{ matcher: matcher, value: value, cumulative: cumulative}]})

          @filters = { completion_urls: completion_url_filters }

          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for non-localized survey"
      end

      context 'when the report is for a survey group' do
        let(:base_survey) { create(:localized_survey, account: account) }
        let(:survey_locale_group) { base_survey.survey_locale_group }
        let(:report_job) { create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { survey_locale_group.surveys }
        let(:localized_report?) { true }

        before do
          duplicated_survey = base_survey.duplicate.tap(&:save)
          first_question = base_survey.questions.reload.first
          last_question  = base_survey.questions.last
          duplicated_question = duplicated_survey.questions.reload.first
          first_question.update(next_question_id: last_question.id)

          udids = 5.times.map { |n| "00000000-0000-4000-f000-00000000000#{n}" }
          create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids.first, answers_count: 0, created_at: Time.current,
                 device_type: "desktop")

          first_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[1],
                               answers_count: 1, created_at: 10.minutes.ago, viewed_at: 10.minutes.ago, url: "alpha")
          second_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[2],
                               answers_count: 1, created_at: 5.minutes.ago, viewed_at: 5.minutes.ago, url: "alpha")
          third_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[3],
                               answers_count: 1, created_at: 1.minute.ago, viewed_at: 1.minute.ago, url: "alpha")
          submission4 = create(:submission, device_id: device.id, survey_id: duplicated_survey.id, udid: udids[4], answers_count: 1,
                               created_at: Time.current, url: "xyz")
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)
          create(:answer, question: duplicated_question, possible_answer: duplicated_question.possible_answers.first, submission: submission4,
                 created_at: submission4.created_at)

          matcher = "contains"
          value = "a"
          cumulative = false

          completion_url_filters = [CompletionUrlFilter.new(matcher, value, cumulative: cumulative)]
          report_job.update(filters: {completion_urls: [{ matcher: matcher, value: value, cumulative: cumulative}]})

          @filters = { completion_urls: completion_url_filters }

          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for localized survey" do
          let(:reportee) { survey_locale_group }
        end
      end
    end

    describe "When a market filter is applied" do
      context 'when the report is for a survey group' do
        let(:base_survey) { create(:localized_survey, account: account) }
        let(:survey_locale_group) { base_survey.survey_locale_group }
        let(:report_job) { create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { survey_locale_group.surveys }
        let(:localized_report?) { true }

        before do
          duplicated_survey = base_survey.duplicate.tap(&:save)
          first_question = base_survey.questions.reload.first
          last_question  = base_survey.questions.last
          duplicated_question = duplicated_survey.questions.reload.first
          first_question.update(next_question_id: last_question.id)

          udids = 5.times.map { |n| "00000000-0000-4000-f000-00000000000#{n}" }
          create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids.first, answers_count: 0, created_at: Time.current)

          first_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[1],
                               answers_count: 1, created_at: 10.minutes.ago, viewed_at: 10.minutes.ago)
          second_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[2],
                               answers_count: 1, created_at: 5.minutes.ago, viewed_at: 5.minutes.ago)
          third_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[3],
                               answers_count: 1, created_at: 1.minute.ago, viewed_at: 1.minute.ago)
          submission4 = create(:submission, device_id: device.id, survey_id: duplicated_survey.id, udid: udids[4], answers_count: 1,
                               created_at: Time.current)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)
          create(:answer, question: duplicated_question, possible_answer: duplicated_question.possible_answers.first, submission: submission4,
                 created_at: submission4.created_at)

          market_ids = [base_survey.id]
          report_job.update(filters: {market_ids: market_ids})
          @filters = { market_ids: market_ids }
          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for localized survey" do
          let(:reportee) { survey_locale_group }
        end
      end
    end

    describe "Date Range" do
      context 'when the report is for a survey' do
        let(:survey) { create(:survey, account: account) }
        let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { [survey] }
        let(:localized_report?) { false }

        before do
          first_question = survey.reload.questions.first
          last_question = survey.questions.last
          first_question.update(next_question_id: last_question.id)

          create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: timezone.parse('2017-02-28  23:59:59'))
          first_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, answers_count: 1,
                               created_at: timezone.parse('2017-03-01 00:00:00'), viewed_at: timezone.parse('2017-03-01 00:00:00'))
          second_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: third_udid, answers_count: 1,
                               created_at: timezone.parse('2017-03-01  20:00:00'), viewed_at: timezone.parse('2017-03-01  20:00:00'))
          third_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: fourth_udid, answers_count: 1,
                               created_at: timezone.parse('2017-03-01  20:20:00'), viewed_at: timezone.parse('2017-03-01  20:20:00'))

          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)

          time_range = timezone.parse('2017-03-01').beginning_of_day..timezone.parse('2017-03-01').end_of_day
          @filters = { date_range: time_range }
          report_job.update(filters: @filters)
          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for non-localized survey"
      end

      context 'when the report is for a survey group' do
        let(:base_survey) { create(:localized_survey, account: account) }
        let(:survey_locale_group) { base_survey.survey_locale_group }
        let(:report_job) { create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email) }
        let(:reportee_surveys) { survey_locale_group.surveys }
        let(:localized_report?) { true }

        before do
          duplicated_survey = base_survey.duplicate.tap(&:save)
          first_question = base_survey.questions.reload.first
          last_question  = base_survey.questions.last
          duplicated_question = duplicated_survey.questions.reload.first
          first_question.update(next_question_id: last_question.id)

          travel_to(timezone.now)
          time_range = timezone.now.beginning_of_day..timezone.now.end_of_day
          @filters = { date_range: time_range }
          time_out_of_range = timezone.now.yesterday

          udids = 5.times.map { |n| "00000000-0000-4000-f000-00000000000#{n}" }
          create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids.first, answers_count: 0, created_at: time_out_of_range)

          first_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[1],
                               answers_count: 1, created_at: time_range.first, viewed_at: time_range.first)
          second_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[2],
                               answers_count: 1, created_at: time_range.first + 1.hour, viewed_at: time_range.first + 1.hour)
          third_submission = create(:submission, device_id: device.id, survey_id: base_survey.id, udid: udids[3],
                               answers_count: 1, created_at: time_range.last - 1.hour, viewed_at: time_range.last - 1.hour)
          submission4 = create(:submission, device_id: device.id, survey_id: duplicated_survey.id, udid: udids[4], answers_count: 1,
                               created_at: time_range.last - 1.second) # using exactly time_range.last causes comparison problems

          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: first_submission,
                 created_at: first_submission.created_at)
          create(:answer, question: first_question, possible_answer: first_question.possible_answers.first, submission: second_submission,
                 created_at: second_submission.created_at)
          create(:answer, question: last_question, possible_answer: last_question.possible_answers.first, submission: third_submission,
                 created_at: third_submission.created_at)
          create(:answer, question: duplicated_question, possible_answer: duplicated_question.possible_answers.first, submission: submission4,
                 created_at: submission4.created_at)
          travel_back

          report_job.update(filters: @filters)
          @xlsx_package = worker.perform(report_job.id)
        end

        it_behaves_like "report worker output for localized survey" do
          let(:reportee) { survey_locale_group }
        end
      end
    end
  end

  # TODO: Support free text question in ReportHelper & delete this
  describe 'Response summaries sheet' do
    it 'skips possible answer stats for free text questions' do
      survey = create(:survey_with_one_free_question, account: account)
      free_text_question = survey.reload.questions.first
      free_text_question.update(content: 'free text content')
      single_choice_quesiton = create(:question, content: 'single choice content', survey: survey, position: 1)

      report_job = create(:report_job, survey: survey, user: user, current_user_email: current_user_email)
      @xlsx_package = worker.perform(report_job.id)

      index = 2 # headers
      expect(response_summaries_worksheet(@xlsx_package)).to have_value(free_text_question.content).at(index, 0)
      expect(response_summaries_worksheet(@xlsx_package)).to have_cells([nil]).in_row(index + 1) # empty row between questions
      expect(response_summaries_worksheet(@xlsx_package)).to have_value(single_choice_quesiton.content).at(index + 2, 0)
    end

    describe "Custom content link click reporting" do
      context "when custom content link click tracking is enabled" do
        context "when the survey has a custom content question with a link" do
          let(:survey) { create(:survey_with_one_custom_question, account: account) }
          let(:question) { survey.reload.questions.first }
          let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }

          before do
            account.update(custom_content_link_click_enabled: true)

            2.times do
              custom_content_link = create(:custom_content_link, custom_content_question: question)
              create(:custom_content_link_click, custom_content_link: custom_content_link)
            end

            @xlsx_package = worker.perform(report_job.id)
            @total_clicks_for_question = question.custom_content_links.sum(&:click_count)
          end

          it "has a row for the question's content" do
            expect(response_summaries_worksheet(@xlsx_package)).to have_value(question.content).at(2, 0)
          end

          it "has a subheader for the question links" do
            answer_stats_last_row_index = 3

            expect(response_summaries_worksheet(@xlsx_package)).to have_cells(
              [nil]
            ).in_row(answer_stats_last_row_index)

            expect(response_summaries_worksheet(@xlsx_package)).to have_cells(
              [nil, nil, nil, "Clicks", "Share"]
            ).in_row(answer_stats_last_row_index + 1)

            expect(response_summaries_worksheet(@xlsx_package)).to have_cells(
              [question.content, nil, nil, @total_clicks_for_question]
            ).in_row(answer_stats_last_row_index + 2)
          end

          it "has a row for each of the question's links" do
            answer_stats_last_row_index = 6

            question.custom_content_links.order(:link_text).each_with_index do |custom_content_link, i|
              click_count = custom_content_link.click_count
              click_share = percent_of(click_count, @total_clicks_for_question)

              expected_cells = [
                "  #{custom_content_link.link_text}",
                custom_content_link.link_url,
                nil, # padding
                click_count,
                click_share
              ]

              expect(response_summaries_worksheet(@xlsx_package)).to have_cells(expected_cells).in_row(answer_stats_last_row_index + i)
            end
          end
        end
      end
    end
  end

  describe 'Email' do
    let(:email_body) { ActionMailer::Base.deliveries.last.html_part.body.to_s }
    let(:parsed_email) { Nokogiri::HTML.parse(email_body) }

    describe 'Recipient' do
      let!(:base_survey) { create(:localized_survey, account: account) }
      let(:report_job) { create(:report_job, survey_locale_group: base_survey.survey_locale_group, status: :created, user: user, current_user_email: current_user_email) }

      context 'when the owner of a survey initiated the worker' do
        it 'sends email to the owner' do
          owner_email = 'owner@test.com'
          report_job.update(current_user_email: owner_email)
          worker.perform(report_job.id)
          recipient_email = ActionMailer::Base.deliveries.last.to.first
          expect(recipient_email).to eq owner_email
        end
      end

      context 'when someone initiated the worker through the "Login As" feature' do
        it 'sends email to alerts@pulseinsights.com' do
          sudoer_user_id = 1
          sudoer_email = 'sudo@test.com'
          report_job.update(sudo_from_id: sudoer_user_id, current_user_email: sudoer_email)
          worker.perform(report_job.id)
          recipient_email = ActionMailer::Base.deliveries.last.to.first
          expect(recipient_email).not_to eq sudoer_email
          expect(recipient_email).to eq 'alerts@pulseinsights.com'
        end
      end
    end

    describe 'Attachment(XLSX)' do
      # The report name uses a timestamp, so these tests may
      # fail intermittently if we do not stop time
      before do
        freeze_time
      end

      after do
        unfreeze_time
      end

      context 'when it is survey' do
        it 'gives correct name to survey xlsx file' do
          survey = create(:survey, account: account)
          report_job = create(:report_job, survey: survey, user: user, current_user_email: current_user_email)

          submission = create(:submission, survey: survey, device: device, answers_count: 1)
          create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first)

          expected_filename = "Pulse Insights Report #{survey.name.parameterize} #{Time.current.strftime("%F %s")}.xlsx"
          worker.perform(report_job.id)

          xlsx_file = ActionMailer::Base.deliveries.last.attachments.first
          expect(xlsx_file.filename).to eq expected_filename
        end
      end

      context 'when it is survey group' do
        it 'gives correct name to survey group xlsx file' do
          base_survey = create(:localized_survey, account: account)
          survey_group = base_survey.survey_locale_group
          survey_group_name = 'Survey Group Name Test'
          survey_group.update(name: survey_group_name)
          report_job = create(:report_job, survey_locale_group: survey_group, user: user, current_user_email: current_user_email)

          submission = create(:submission, survey: base_survey, device: device, answers_count: 1)
          create(:answer, submission: submission, question: base_survey.questions.first, possible_answer: base_survey.questions.first.possible_answers.first)

          expected_filename = "Pulse Insights Localization Report #{survey_group.name.parameterize} #{Time.current.strftime("%F %s")}.xlsx"
          worker.perform(report_job.id)

          xlsx_file = ActionMailer::Base.deliveries.last.attachments.first
          expect(xlsx_file.filename).to eq expected_filename
        end
      end
    end

    describe 'Attachment(CSV)' do
      before do
        allow(worker).to receive(:individual_rows_exceeded?) { true }
        allow(worker).to receive(:upload_csv_file) { "test.csv" }
      end

      # TODO: when it is survey

      context 'when it is survey group' do
        it 'contains a CSV file link when the size of "Individual rows" sheet exceeds the threshold' do
          base_survey = create(:localized_survey, account: account)
          question = base_survey.questions.first

          5.times do
            create(:submission, survey: base_survey, device: device, answers_count: 1).tap do |submission|
              create(:answer, submission: submission, question: question, possible_answer: question.possible_answers.first)
            end
          end

          report_job = create(:report_job, survey_locale_group: base_survey.survey_locale_group, user: user, current_user_email: current_user_email)
          worker.perform(report_job.id)

          expect(email_body.scan(/test.csv/).length).to eq 1

          # TODO: test CSV content
        end
      end
    end

    describe 'Template Header' do
      context 'when it is survey' do
        it 'uses survey name' do
          survey_name = 'Survey Name Test'
          survey = create(:survey, name: survey_name, account: account)
          report_job = create(:report_job, survey: survey, user: user, current_user_email: current_user_email)

          submission = create(:submission, survey: survey, device: device, answers_count: 1)
          create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.questions.first.possible_answers.first)

          worker.perform(report_job.id)

          expect(parsed_email.xpath("//div[@class='survey_name']").text).to eq survey_name
        end
      end

      context 'when it is survey group' do
        it 'uses survey group name' do
          base_survey = create(:localized_survey, account: account)
          survey_group = base_survey.survey_locale_group
          survey_group_name = 'Survey Group Name Test'
          survey_group.update(name: survey_group_name)
          report_job = create(:report_job, survey_locale_group: survey_group, user: user, current_user_email: current_user_email)

          submission = create(:submission, survey: base_survey, device: device, answers_count: 1)
          create(:answer, submission: submission, question: base_survey.questions.first, possible_answer: base_survey.questions.first.possible_answers.first)

          worker.perform(report_job.id)

          expect(parsed_email.xpath("//div[@class='survey_name']").text).to eq survey_group_name
        end
      end
    end

    describe 'Survey stats' do
      context 'when it is survey' do
        it "displays the survey's stats" do
          survey = create(:survey, account: account)
          create_list(:submission, 10, survey: survey, device: device, answers_count: 1)                          # submission
          create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: Time.current) # viewed_impression
          create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: nil)          # impression

          report_job = create(:report_job, survey: survey, user: user, current_user_email: current_user_email)
          worker.perform(report_job.id)
          expect_reportee_stats(survey)
        end
      end

      context 'when it is survey group' do
        it 'displays stats that combine all surveys within the group' do
          base_survey = create(:localized_survey, account: account)
          dup_survey = base_survey.duplicate.tap(&:save)
          survey_locale_group = base_survey.survey_locale_group
          dup_survey.add_to_localization_group(survey_locale_group.id, 'test_lang_code')

          survey_locale_group.surveys.each do |survey|
            create_list(:submission, 10, survey: survey, device: device, answers_count: 1)                          # submission
            create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: Time.current) # viewed_impression
            create_list(:submission, 10, survey: survey, device: device, answers_count: 0, viewed_at: nil)          # impression
          end

          report_job = create(:report_job, survey_locale_group: survey_locale_group, user: user, current_user_email: current_user_email)
          worker.perform(report_job.id)
          expect_reportee_stats(survey_locale_group)
        end
      end

      def expect_reportee_stats(reportee)
        expect(parsed_email.xpath("//div[@class='impressions']/div[@class='count']").first.text).to eq reportee.blended_impressions_count.to_s
        expect(parsed_email.xpath("//div[@class='submissions']/div[@class='count']").first.text).to eq reportee.submissions_count.to_s
        expect(parsed_email.xpath("//div[@class='submission_rate']/div[@class='count']").first.text).to eq reportee.human_submission_rate
      end
    end

    describe 'Question stats' do
      # TODO: when it is survey

      context 'when it is survey group' do
        it 'displays stats that include all the child surveys within the group' do
          base_survey = create(:localized_survey, account: account)
          dup_survey = base_survey.duplicate.tap(&:save)
          survey_locale_group = base_survey.survey_locale_group
          dup_survey.add_to_localization_group(survey_locale_group.id, 'test_lang_code')

          survey_locale_group.surveys.each do |survey|
            survey.questions.each do |question|
              question.possible_answers.each do |possible_answer|
                create(:submission, survey: survey, device: device, answers_count: 1).tap do |submission|
                  create(:answer, submission: submission, question: question, possible_answer: possible_answer)
                end
              end
            end
          end

          report_job = create(:report_job, survey_locale_group: base_survey.survey_locale_group, user: user, current_user_email: current_user_email)
          worker.perform(report_job.id)

          parsed_email.xpath("//div[@class='responses-count']").each_with_index do |element, index|
            question_group = survey_locale_group.question_locale_groups[index]
            expect(element.text).to eq "\n#{question_group.answers_count} Responses\n"
          end

          response_counts =
            survey_locale_group.question_locale_groups.map do |question_group|
              question_group.possible_answer_locale_groups.map(&:answers_count)
            end.flatten
          parsed_email.xpath("//div[@class='answer']/div[@class='progress-custom']//td[1]").each_with_index do |element, index|
            expect(element.text).to eq "\n#{response_counts[index]}\n"
          end
        end
      end
    end
  end

  # Will be fixed in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  #
  # it 'does not display follow-up submissions' do
  #   expect(Answer.count).to eq(0)
  #
  #   survey = create(:survey, account: account)
  #   first_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, answers_count: 2,
  #                                     created_at: timezone.parse('2017-03-01 00:00:00'))
  #
  #   second_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: third_udid, answers_count: 2,
  #                                     created_at: timezone.parse('2017-03-01 23:59:59'))
  #
  #   question = survey.reload.questions.first
  #   create(
  #     :answer,
  #     question: question,
  #     possible_answer: question.possible_answers.sort_by_position.first,
  #     submission: first_submission,
  #     created_at: first_submission.created_at
  #   )
  #
  #   question = survey.questions.last
  #   create(
  #     :answer,
  #     question: question,
  #     possible_answer: question.possible_answers.sort_by_position.first,
  #     submission: first_submission,
  #     created_at: first_submission.created_at
  #   )
  #
  #   question = survey.questions.first
  #   create(
  #     :answer,
  #     question: question,
  #     possible_answer: question.possible_answers.sort_by_position.first,
  #     submission: second_submission,
  #     created_at: second_submission.created_at
  #   )
  #
  #   question = survey.questions.last
  #   create(
  #     :answer,
  #     question: question,
  #     possible_answer: question.possible_answers.sort_by_position.first,
  #     submission: second_submission,
  #     created_at: second_submission.created_at
  #   )
  #   expect(Answer.count).to eq(4)
  #
  #   report_job = create(:report_job, survey: survey)
  #   res = worker.perform(report_job.id,
  #                        nil,
  #                        timezone.parse('2017-03-01').beginning_of_day.to_s,
  #                        timezone.parse('2017-03-01').end_of_day.to_s,
  #                        nil,
  #                        nil,
  #                        nil)
  #
  #   #### SUMMARY STATS BY DAY
  #   expect(res.workbook.worksheets[1].rows[2].cells[1].value).to eq 2
  #   expect(res.workbook.worksheets[1].rows[2].cells[3].value).to eq 2
  #
  #   expect(res.workbook.worksheets[1].rows[3].cells[1].value).to eq 2
  #   expect(res.workbook.worksheets[1].rows[3].cells[3].value).to eq 2
  #
  #   ##### RESPONSE SUMMARIES
  #   expect(res.workbook.worksheets[2].rows[2].cells[3].value).to eq 2
  #   expect(res.workbook.worksheets[2].rows[3].cells[3].value).to eq 2
  #   expect(res.workbook.worksheets[2].rows[6].cells[3].value).to eq 2
  #   expect(res.workbook.worksheets[2].rows[7].cells[3].value).to eq 2
  #
  #   #### INDIVIDUAL ROWS
  #   expect(res.workbook.worksheets[3].rows[1].cells[0].value).to eq '03/01/2017'
  #   expect(res.workbook.worksheets[3].rows[1].cells[1].value).to eq '23:59:59'
  #   expect(res.workbook.worksheets[3].rows[2].cells[0].value).to eq '03/01/2017'
  #   expect(res.workbook.worksheets[3].rows[2].cells[1].value).to eq '23:59:59'
  #   expect(res.workbook.worksheets[3].rows[3].cells[0].value).to eq '03/01/2017'
  #   expect(res.workbook.worksheets[3].rows[3].cells[1].value).to eq '00:00:00'
  #   expect(res.workbook.worksheets[3].rows[4].cells[0].value).to eq '03/01/2017'
  #   expect(res.workbook.worksheets[3].rows[4].cells[1].value).to eq '00:00:00'
  # end

  context 'when individual_rows exceeds limit' do
    let(:survey) { create(:survey, account: account) }
    let!(:first_question) { survey.questions.first }
    let!(:second_question) { survey.questions.reload.last }

    let!(:first_question_first_possible_answer) { survey.questions.first.possible_answers.first }
    let!(:last_question_first_possible_answer) { survey.questions.last.possible_answers.first }

    let!(:first_device) { create(:device, udid: second_udid) }
    let!(:second_device) { create(:device, udid: third_udid) }
    let!(:third_device) { create(:device, udid: fourth_udid) }

    let(:submission) { create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0, created_at: timezone.parse('2017-02-28 23:59:59')) }
    let!(:first_submission) { create(:submission, device_id: first_device.id, survey_id: survey.id, udid: second_udid, answers_count: 1, created_at: timezone.parse('2017-03-01 00:00:00')) }
    let!(:second_submission) { create(:submission, device_id: second_device.id, survey_id: survey.id, udid: third_udid, answers_count: 1, created_at: timezone.parse('2017-03-01 23:59:59')) }
    let!(:third_submission) { create(:submission, device_id: third_device.id, survey_id: survey.id, udid: fourth_udid, answers_count: 1, created_at: timezone.parse('2017-03-01 23:59:59')) }

    let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }

    before do
      create(:answer, question: first_question, possible_answer: first_question_first_possible_answer,
             submission: first_submission, created_at: first_submission.created_at)
      create(:answer, question: first_question, possible_answer: first_question_first_possible_answer,
             submission: second_submission, created_at: second_submission.created_at)
      create(:answer, question: second_question, possible_answer: last_question_first_possible_answer,
             submission: third_submission, created_at: third_submission.created_at)
    end

    it 'generate a csv file' do
      allow(worker).to receive(:individual_rows_exceeded?) { true }
      allow(worker).to receive(:upload_csv_file) { "report_worker_test.csv" }
      allow(worker).to receive(:upload_xlsx_file) { "report_worker_test.xlsx" }

      report_job.update(filters: {date_range: (timezone.parse('2017-03-01').beginning_of_day..timezone.parse('2017-03-01').end_of_day)})
      res = worker.perform(report_job.id)
      rows = CSV.parse(File.read(worker.individual_rows_filepath), headers: true)

      expect(rows[0]['Date']).to eq '03/01/2017'
      expect(rows[0]['Time']).to eq '23:59:59'
      expect(rows[0]['Question']).to eq first_question.content
      expect(rows[0]['SurveyID'].to_i).to eq survey.id
      expect(rows[0]['DeviceUDID']).to eq second_device.udid

      expect(rows[1]['Date']).to eq '03/01/2017'
      expect(rows[1]['Time']).to eq '23:59:59'
      expect(rows[1]['Question']).to eq second_question.content
      expect(rows[1]['SurveyID'].to_i).to eq survey.id
      expect(rows[1]['DeviceUDID']).to eq third_device.udid

      expect(rows[2]['Date']).to eq '03/01/2017'
      expect(rows[2]['Time']).to eq '00:00:00'
      expect(rows[2]['Question']).to eq first_question.content
      expect(rows[2]['SurveyID'].to_i).to eq survey.id
      expect(rows[2]['DeviceUDID']).to eq first_device.udid

      expect(res.workbook.sheet_by_name('Individual rows')).to be_nil

      # expect to find that CSV file URL in the e-mail
      mail = ActionMailer::Base.deliveries.last

      expect(mail.html_part.body.raw_source.scan(/report_worker_test.csv/).length).to eq 1
    end
  end

  describe 'IP Address' do
    let(:survey) { create(:survey, account: account) }
    let(:report_job) { create(:report_job, survey: survey, user: user, current_user_email: current_user_email) }

    before do
      @submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 1, ip_address: '10.000.00',
                           created_at: timezone.parse('2021-06-01 03:00:00'))
      @second_submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: second_udid, answers_count: 1, ip_address: '10.000.01',
                           created_at: timezone.parse('2021-06-01  6:00:00'))
      question = survey.questions.first
      create(:answer, question: question, possible_answer: question.possible_answers.first, submission: @submission, created_at: @submission.created_at)
      create(:answer, question: question, possible_answer: question.possible_answers.first,
             submission: @second_submission, created_at: @second_submission.created_at)
    end

    context 'when the policy is store_none' do
      it 'does not contain any ip address' do
        account.update(ip_storage_policy: :store_none)

        xlsx_package = worker.perform(report_job.id)

        # Individual Rows
        ip_address_index = 13
        individual_rows_sheet = individual_responses_worksheet(xlsx_package)

        ip_addresses = individual_rows_sheet.rows[1..].map { |row| row.cells[ip_address_index].value } # rows[0] is header
        expect(ip_addresses.compact).to eq []
        # Devices
        ip_address_index = 11
        devices_sheet = device_worksheet(xlsx_package)
        ip_addresses = devices_sheet.rows[1..].map { |row| row.cells[ip_address_index].value } # rows[0] is header
        expect(ip_addresses.compact).to eq []
      end
    end

    context 'when the policy is not store_none' do
      it 'contains ip addresses' do
        account.update(ip_storage_policy: :store_full)

        xlsx_package = worker.perform(report_job.id)

        # Individual Rows
        ip_address_index = 13
        individual_rows_sheet = individual_responses_worksheet(xlsx_package)
        expect(individual_rows_sheet.rows[1].cells[ip_address_index].value).to eq @second_submission.ip_address
        expect(individual_rows_sheet.rows[2].cells[ip_address_index].value).to eq @submission.ip_address
        # Devices
        ip_address_index = 11
        devices_sheet = device_worksheet(xlsx_package)
        expect(devices_sheet.rows[1].cells[ip_address_index].value).to eq @submission.ip_address
        expect(devices_sheet.rows[2].cells[ip_address_index].value).to eq @second_submission.ip_address
      end
    end
  end

  it_behaves_like 'report worker with viewed impressions considered' do
    let(:report_object) { create(:report_job, survey: reportee, user: user, current_user_email: current_user_email) }
    let(:reportee) { create(:survey) }
    let(:date_format) { "%m/%d/%y" }
  end
end
