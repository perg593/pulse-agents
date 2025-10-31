# frozen_string_literal: true

class ReportMailerPreview < ActionMailer::Preview
  def send_report
    populate_test_records

    data =
      {
        account: Account.last,
        reportee: Survey.last,
        report_name: 'foo.xlsx',
        report_path: 'tmp/foo.xlsx',
        report_url: 'file://tmp/foo.xlsx',
        date_range: Time.now.beginning_of_day..Time.now.end_of_day,
        impressions_count: 50,
        submissions_count: 10,
        submission_rate: '20%'
      }

    ReportMailer.send_report(data, current_user_email: 'test@test.com')
  end

  def localization_report
    populate_test_records

    survey = Survey.last
    survey.localize!

    survey = survey.duplicate.tap(&:save)
    question = survey.questions.first
    Answer.create(text_answer: 'dup test answer', question: question, possible_answer: question.possible_answers.first)

    data =
      {
        account: survey.account,
        reportee: survey.survey_locale_group,
        report_name: 'foo.xlsx',
        report_path: 'tmp/foo.xlsx',
        report_url: 'file://tmp/foo.xlsx',
        date_range: Time.now.beginning_of_day..Time.now.end_of_day,
        impressions_count: 50,
        submissions_count: 10,
        submission_rate: '20%',
        current_user_email: 'test@test.com'
      }

    ReportMailer.localization_report(data)
  end

  private

  def populate_test_records
    account = Account.create(name: 'test account')
    survey = Survey.create(name: 'test survey', account: account)
    question = Question.create(content: 'test question', survey: survey)
    possible_answer = PossibleAnswer.create(content: 'test possible answer', question: question)
    possible_answer2 = PossibleAnswer.create(content: 'test possible answer2', question: question)
    possible_answer3 = PossibleAnswer.create(content: 'test possible answer2', question: question)
    possible_answer4 = PossibleAnswer.create(content: 'test possible answer2', question: question)

    PossibleAnswer.create(content: 'test possible answer2', question: question)
    Answer.create(question: question, possible_answer: possible_answer)
    Answer.create(question: question, possible_answer: possible_answer2)
    Answer.create(question: question, possible_answer: possible_answer3)
    Answer.create(question: question, possible_answer: possible_answer4)

    question = Question.create(content: 'free text question', question_type: :free_text_question, survey: survey)
    5.times { |n| Answer.create(text_answer: "test answer #{n}", question: question) }
  end
end
