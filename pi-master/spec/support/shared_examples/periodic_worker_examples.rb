# frozen_string_literal: true

include PeriodicReportWorkerHelper

shared_context "with shared worker context" do
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }

  let(:worker) { described_class.new }

  before do
    # The stub needs to match the exact usage.
    # { credentials: nil } is not the same as not passing credentials
    keyword_args = aws_credentials ? { credentials: aws_credentials} : {}

    [qc_filename, report_filename].each do |filename|
      allow(worker).to receive(:transfer_to_s3).with(filename, aws_config, **keyword_args).and_return qc_url
    end
  end
end

shared_examples "quality_control_file" do
  include_context "with shared worker context"

  it "generates a quality control file with the expected name" do
    worker.perform
    expect(File.exist?(qc_filepath)).to be true
  end

  it "generates an appropriate header" do
    worker.perform

    report = CSV.read(qc_filepath)
    expect(report[0]).to match_array %w(Feed_Name Record_Count Feed_Size Checksum Data_Period_Start Data_Period_End)
  end

  it "generates a file even when there were no submissions" do
    account = Account.find(described_class.account_ids.first)
    create_survey_in_report_scope(account)

    worker.perform

    report = CSV.read(qc_filepath)
    expect(report.size).to eq 2 # one for the header, one for the survey
  end

  it "generates a file even when there were no submissions in range" do
    account = Account.find(described_class.account_ids.first)
    survey = create_survey_in_report_scope(account)

    create(:submission, survey_id: survey.id, answers_count: 1,
           created_at: 2.months.ago)

    worker.perform

    report = CSV.read(qc_filepath)
    expect(report.size).to eq 2 # one for the header, one for the survey
  end

  it "generates appropriate data for a report with no results" do
    worker.perform

    report  = CSV.read(report_filepath)
    qc_file = CSV.read(qc_filepath, converters: :numeric)

    verify_qc_file_contents(report_filename, report_filepath, qc_filepath, data_start_date, data_end_date)
  end

  it "generates appropriate data for a report with results" do
    account = Account.find(described_class.account_ids.first)
    surveys = 2.times.map { create_survey_in_report_scope(account) }

    surveys.each do |survey|
      create_submission_in_range(survey, device.id, udid)
      submission_with_answer = create_submission_in_range(survey, device.id, udid)
      create_answer_for_submission(submission_with_answer)
    end

    worker.perform

    verify_qc_file_contents(report_filename, report_filepath, qc_filepath, data_start_date, data_end_date)
  end
end

shared_examples "submission_report_file" do
  include_context "with shared worker context"

  it "generates a file with the expected name" do
    worker.perform
    expect(File.exist?(report_filepath)).to be true
  end

  it "generates a file with no data when there was no activity" do
    account = Account.find(described_class.account_ids.first)
    create_survey_in_report_scope(account)

    worker.perform

    report = CSV.read(report_filepath)
    expect(report.size).to eq 1 # the header row
    verify_report_header(report)
  end

  it "generates a file with no data when there is no activity within the relevant date range" do
    account = Account.find(described_class.account_ids.first)
    survey = create_survey_in_report_scope(account)
    out_of_range_submission = create(:submission, survey_id: survey.id, answers_count: 1, created_at: 2.months.ago)

    worker.perform

    report = CSV.read(report_filepath)
    expect(report.size).to eq 1 # the header row
    verify_report_header(report)
  end

  # rubocop:disable RSpec/ExampleLength
  # There are a lot of columns to test
  it "generates a file with the expected data when there is activity" do
    account = Account.find(described_class.account_ids.first)
    survey = create_survey_in_report_scope(account)

    survey.questions.first.possible_answers.sort_by_position.first.update(next_question_id: survey.questions.first.id)

    create_submission_in_range(survey, device.id, udid)

    3.times { create_answer_for_submission(create_submission_in_range(survey, device.id, udid)) }

    answer_with_tags_and_entities = create_answer_for_submission(create_submission_in_range(survey, device.id, udid))

    answer_with_tags_and_entities.update(
      sentiment: {score: 12.1, magnitude: 7.2},
      entities: [
        {name: FFaker::Lorem.word, type: FFaker::Lorem.word}, {name: FFaker::Lorem.word, type: FFaker::Lorem.word}
      ]
    )
    create(:applied_tag, answer: answer_with_tags_and_entities, tag: create(:tag, question: answer_with_tags_and_entities.question))
    create(:automatically_applied_tag, answer: answer_with_tags_and_entities, tag: create(:tag, question: answer_with_tags_and_entities.question))
    create(:device_data, device_id: device.id, account_id: account.id, device_data: { 'name' => 'jonathan' })

    out_of_range_submission = create(
      :submission, device_id: device.id, survey_id: survey.id, udid: udid,
      answers_count: 1, created_at: data_start_date - 1.hour
    )

    create(
      :answer, question: survey.questions.first,
      possible_answer: survey.questions.first.possible_answers.sort_by_position.first,
      submission: out_of_range_submission, created_at: out_of_range_submission.created_at
    )

    worker.perform

    report = CSV.read(report_filepath, converters: :numeric)

    verify_report_header(report)

    expect(report.size).to eq(
      survey.submissions.where(created_at: (data_start_date..data_end_date)).count + 1
    ) # one for each submission, one for the header

    Answer.where(created_at: (data_start_date..data_end_date)).order(:created_at).each_with_index do |answer, answer_index|
      expected_data = [
        account.name,
        account.identifier,
        answer.created_at.strftime("%m/%d/%y"),
        answer.created_at.in_time_zone("GMT").strftime("%H/%M/%S"),
        answer.created_at.strftime("%y-%m-%d %H:%M:%S.%6N"),
        answer.question.content,
        answer.text_of_response,
        answer.tags.pluck(:name).join(","),
        answer.submission.survey.id,
        answer.question.id,
        answer.id,
        answer.next_question_id,
        answer.submission.pageview_count,
        answer.submission.visit_count,
        answer.submission.device_type,
        answer.device.udid,
        answer.submission.client_key,
        answer.submission.url,
        answer.submission.view_name,
        answer.submission.pseudo_event,
        answer.submission.custom_data,
        answer.device_data.to_s,
        answer.sentiment.try(:[], 'score'),
        answer.sentiment.try(:[], 'magnitude')
      ]

      4.times do |i|
        expected_data += if answer.entities && answer.entities.count > i
          [answer.entities[i]['name'], answer.entities[i]['type']]
        else
          [nil, nil]
        end
      end

      expected_data += [
        answer.os,
        answer.browser,
        answer.browser_version.to_s.to_f,
        answer.submission.channel
      ]

      expect(report[answer_index + 1]).to match_array(expected_data)
    end
  end

  def verify_report_header(report)
    expect(report[0]).to contain_exactly("Account Name", "Account ID", "Date", "Time", "Timestamp (UTC)", "Question", "Response", "Tags", "SurveyID", "QuestionID", "ResponseID", "NextQuestionID", "Pageview Count", "Visit Count", "Device Type", "DeviceUDID", "Client Key", "Completion URL", "View Name", "Event", "Context data", "Device data", "Sentiment Score", "Sentiment Magnitude", "Entity 1 name", "Entity 1 type", "Entity 2 name", "Entity 2 type", "Entity 3 name", "Entity 3 type", "Entity 4 name", "Entity 4 type", "OS", "Browser", "Browser version", "Channel")
  end
end

shared_examples "delivery_check" do
  it "is not considered delivered if there are no WorkerOutputCopy records" do
    expect(described_class.delivered_as_expected?).to be(false)
  end
end

shared_examples "historical_report" do
  include_context "with shared worker context"

  before do
    @account = Account.find(described_class.account_ids.first)
    @surveys = 2.times.map { create_survey_in_report_scope(@account) }

    (("2020-10-02".to_date)..("2021-10-08".to_date)).each_with_index do |start_date, i|
      next unless i % 7 == 0 # Only generate submissions for every seven days, just to speed up testing

      @surveys.each do |survey|
        boilerplate_params = {device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0}
        create(:submission, boilerplate_params.merge(created_at: start_date))

        submission_with_answer = create(:submission, boilerplate_params.merge(created_at: start_date))

        create(
          :answer, question: survey.questions.first,
          possible_answer: survey.questions.first.possible_answers.sort_by_position.first,
          submission: submission_with_answer, created_at: submission_with_answer.created_at
        )
      end
    end

    @historical_start_date = "2020-10-02".to_date
    @historical_end_date = "2021-05-09".to_date
  end

  it 'takes parameters specifying a date range' do
    worker.perform(start_date: 1.year.ago, end_date: 2.months.ago)
  end

  it 'compiles a submission report across a wide range with no grouping' do
    worker.perform(start_date: @historical_start_date, end_date: @historical_end_date)

    filters = {
      date_range: (@historical_start_date.beginning_of_day..@historical_end_date.end_of_day)
    }

    filters.merge!(market_ids: described_class.survey_ids) if described_class.survey_ids

    answer_scope = Answer.filtered_answers(Answer.all, filters: filters)

    report = CSV.read(report_filepath, converters: :numeric)
    expect(report.count).to eq(1 + answer_scope.count)
  end

  it 'generates a submission report quality control file covering the time range' do
    worker.perform(start_date: @historical_start_date, end_date: @historical_end_date)

    verify_qc_file_contents(
      report_filename, report_filepath,
      qc_filepath, @historical_start_date.beginning_of_day, @historical_end_date.end_of_day
    )
  end
end
