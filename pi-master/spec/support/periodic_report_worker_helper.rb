# frozen_string_literal: true

module PeriodicReportWorkerHelper
  def create_survey_in_report_scope(account)
    survey_args = {
      account: account,
      name: FFaker::Lorem.phrase
    }

    if described_class.survey_ids.present?
      eligible_survey_id = described_class.survey_ids.detect do |survey_id|
        !Survey.where(id: survey_id).exists?
      end

      survey_args.merge!(id: eligible_survey_id)
    end

    survey = create(:survey, **survey_args)
  end

  def create_submission_in_range(survey, device_id, udid)
    ms_offset = Submission.last&.id.to_i
    boilerplate_params = {device_id: device_id, survey_id: survey.id, udid: udid, answers_count: 0}
    create(:submission, boilerplate_params.merge(created_at: data_start_date + 1.day + ms_offset))
  end

  def create_answer_for_submission(submission)
    survey = submission.survey

    create(
      :answer, question: survey.questions.first,
      possible_answer: survey.questions.first.possible_answers.sort_by_position.first,
      submission: submission, created_at: submission.created_at
    )
  end

  def verify_qc_file_contents(report_filename, report_filepath, qc_filepath, start_date, end_date)
    report = CSV.read(report_filepath)
    qc_file = CSV.read(qc_filepath, converters: :numeric)

    sha256 = Digest::SHA256.file(report_filepath)
    report_checksum = sha256.hexdigest

    expect(qc_file[1]).to contain_exactly(report_filename, report.count - 1, File.size(report_filepath), report_checksum, start_date.strftime("%m/%d/%y"),
                                          end_date.strftime("%m/%d/%y"))
  end
end
