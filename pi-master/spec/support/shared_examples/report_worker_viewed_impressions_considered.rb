# frozen_string_literal: true

RSpec.shared_examples "report worker with viewed impressions considered" do
  # ReportJob or ScheduledReport
  def report_object
    raise NotImplementedError, "You must implement 'report_object'"
  end

  # Survey or SurveyLocaleGroup
  def reportee
    raise NotImplementedError, "You must implement 'reportee'"
  end

  # ReportWorker and IndividualReportWorker use different date formats in a few excel sheets
  def date_format
    raise NotImplementedError, "You must implement 'date_format'"
  end

  describe 'submission rate' do
    let(:worker) { described_class.new }

    let(:account) { reportee.account }

    let(:test_date) { Date.new(2021, 2, 2).strftime(date_format) }

    before do
      create(:submission, survey_id: reportee.id, created_at: timezone.parse('2021-2-2 3:00'))
      create(:submission, survey_id: reportee.id, created_at: timezone.parse('2021-2-2 3:05'))
      create(:submission, survey_id: reportee.id, created_at: timezone.parse('2021-2-2 4:00'), viewed_at: timezone.parse('2021-2-2 4:00'))
      create(:submission, survey_id: reportee.id, created_at: timezone.parse('2021-2-2 4:00'), viewed_at: timezone.parse('2021-2-2 4:00'))
      create(:submission, survey_id: reportee.id, answers_count: 1, created_at: timezone.parse('2021-2-2 4:05'), viewed_at: timezone.parse('2021-2-2 4:05'))
      create(:submission, survey_id: reportee.id, answers_count: 1, created_at: timezone.parse('2021-2-2 4:10'), viewed_at: timezone.parse('2021-2-2 4:10'))
    end

    describe 'excel' do
      context 'when the viewed impression feature has been on for the following day' do
        it 'calculates a submission rate based on viewed impressions' do
          account.update(viewed_impressions_enabled_at: Time.new(2021, 2, 1))

          perform_worker

          submission_rate = "#{(reportee.submissions.count * 100 / reportee.viewed_impressions.count.to_f).round}%"
          expected_cells = [test_date, reportee.viewed_impressions.count, reportee.submissions.count, submission_rate]
          expect(aggregate_results_by_day_sheet).to have_cells(expected_cells).in_row(2)
        end
      end

      context 'when the viewed impression feature has not been on for the following day' do
        it 'calculates a submission rate based on served impressions' do
          account.update(viewed_impressions_enabled_at: Time.new(2021, 2, 2))

          perform_worker

          submission_rate = "#{(reportee.submissions.count * 100 / reportee.impressions.count.to_f).round}%"
          expect(aggregate_results_by_day_sheet).to have_cells([test_date, reportee.impressions.count, reportee.submissions.count, submission_rate]).in_row(2)
        end
      end

      it 'calculates the total rate based on a mixture of both served and viewed impressions' do
        account.update(viewed_impressions_enabled_at: Time.new(2021, 2, 2))
        start_at = account.viewed_impressions_calculation_start_at

        %w(2021-2-1 2021-2-4).each do |date|
          create(:submission, survey_id: reportee.id, created_at: timezone.parse("#{date} 3:00"))
          create(:submission, survey_id: reportee.id, created_at: timezone.parse("#{date} 3:05"))
          create(:submission, survey_id: reportee.id, created_at: timezone.parse("#{date} 4:00"), viewed_at: timezone.parse("#{date} 4:00"))
          create(:submission, survey_id: reportee.id, created_at: timezone.parse("#{date} 4:00"), viewed_at: timezone.parse("#{date} 4:00"))
          create(:submission, survey_id: reportee.id, answers_count: 1, created_at: timezone.parse("#{date} 4:05"), viewed_at: timezone.parse("#{date} 4:05"))
          create(:submission, survey_id: reportee.id, answers_count: 1, created_at: timezone.parse("#{date} 4:10"), viewed_at: timezone.parse("#{date} 4:10"))
        end

        perform_worker

        blended_impression_count = reportee.impressions.where(created_at: ...start_at).or(reportee.viewed_impressions.where(created_at: start_at..)).count
        blended_rate = "#{(reportee.submissions.count * 100 / blended_impression_count.to_f).round}%"
        expect(aggregate_results_by_day_sheet).to have_cells(['TOTAL', blended_impression_count, reportee.submissions.count, blended_rate]).in_row(5)
      end
    end

    describe 'email' do
      let(:parsed_mail) { Nokogiri::HTML.parse(ActionMailer::Base.deliveries.last.html_part.body.to_s) }

      context 'when the viewed impression feature has been on for the following day' do
        before do
          account.update(viewed_impressions_enabled_at: Time.new(2021, 2, 1))
        end

        it 'calculates the total submission rate based on viewed impressions' do
          worker.perform(report_object.id)

          submission_rate = parsed_mail.css('div.submission_rate div.count').first.text
          expect(submission_rate).to include (reportee.submissions_count * 100.0 / reportee.viewed_impressions_count).round.to_s
        end
      end

      context 'when the viewed impression feature has not been on for the following day' do
        before do
          account.update(viewed_impressions_enabled_at: Time.new(2021, 2, 2))
        end

        it 'calculates the total submission rate based on served impressions' do
          worker.perform(report_object.id)

          submission_rate = parsed_mail.css('div.submission_rate div.count').first.text
          expect(submission_rate).to include (reportee.submissions_count * 100.0 / reportee.impressions_count).round.to_s
        end
      end

      it 'respects the date range filter' do
        skip('Custom date range is not supported yet') if report_object.is_a? ScheduledReport

        date_range = Time.new(2021, 2, 1, 5)..Time.new(2021, 2, 2, 5)
        account.update(viewed_impressions_enabled_at: date_range.first)
        report_object.update(filters: { date_range: date_range })
        worker.perform(report_object.id)

        impressions_count = parsed_mail.css('div.impressions div.count').first.text
        submissions_count = parsed_mail.css('div.submissions div.count').first.text
        submission_rate = parsed_mail.css('div.submission_rate div.count').first.text

        filters = { date_range: date_range }
        expect(impressions_count).to eq reportee.blended_impressions_count(filters: filters).to_s
        expect(submissions_count).to eq reportee.submissions_count(filters: filters).to_s
        expect(submission_rate).to eq "#{(reportee.submissions_count(filters: filters) * 100 /
          reportee.viewed_impressions_count(filters: filters).to_f).round}%"
      end
    end

    def perform_worker
      @xlsx_package = Array.wrap(worker.perform(report_object.id))
    end

    def aggregate_results_by_day_sheet
      @xlsx_package.first.workbook.worksheets[1]
    end
  end
end
