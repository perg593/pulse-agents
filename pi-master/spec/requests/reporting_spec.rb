# frozen_string_literal: true
require 'spec_helper'

describe 'Reporting' do
  before do
    Survey.delete_all
    Question.delete_all
    Answer.delete_all
    Submission.delete_all
    PossibleAnswer.delete_all
    Device.delete_all
    User.delete_all
    Account.delete_all
  end

  it "is a placeholder" do
    expect(42).not_to be_nil
  end

  # TODO: Write replacements for these three tests using a React testing library
  #
  # it 'displays 4 cards with impressions, viewed impressions, submissions, submission rate and days active' do
  #   create_simple_survey
  #   login_and_go_to_reporting
  #
  #   assert_select '#impression_sum_chart'
  #   assert_select '.chart.impressions > .value', text: '0'
  #   assert_select '#viewed_impression_sum_chart'
  #   assert_select '.chart.viewed_impressions > .value', text: '0'
  #   assert_select '#submission_sum_chart'
  #   assert_select '.chart.submissions > .value', text: '0'
  #   assert_select '#submission_rate_chart'
  #   assert_select '.chart.rate > .value', text: '0'
  #   assert_select '.days-active'
  #   assert_select '.days-active > .value', text: '2'
  # end

  # it 'displays results for single choice question' do
  #   create_simple_survey
  #   login_and_go_to_reporting
  #
  #   assert_select '.question:first-of-type > .content-responses-count > .content', text: @question.content
  #   assert_select '.question:first-of-type > .content-responses-count > .responses-count', text: '1 Response'
  #   assert_select '.question:first-of-type > .answers > .answer:first-of-type > .answer-content', text: @question.possible_answers.first.content
  #   assert_select '.question:first-of-type > .answers > .answer:first-of-type > .progress-custom > .progress-bar > .answer-count', text: '1'
  #   assert_select '.question:first-of-type > .answers > .answer:last > .answer-content', text: @question.possible_answers.last.content
  #   assert_select '.question:first-of-type > .answers > .answer:last > .progress-custom > .progress-bar > .answer-count', text: '0'
  #
  #   @survey.questions.reload
  #   assert_select '.question:last > .content-responses-count > .content', text: @survey.questions.last.content
  #   assert_select '.question:last > .content-responses-count > .responses-count', text: '0 Responses'
  #   assert_select '.question:last > .answers > .answer:first-of-type > .answer-content', text: @survey.questions.last.possible_answers.first.content
  #   assert_select '.question:last > .answers > .answer:first-of-type > .progress-custom > .progress-bar > .answer-count', text: '0'
  #   assert_select '.question:last > .answers > .answer:last > .answer-content', text: @survey.questions.last.possible_answers.last.content
  #   assert_select '.question:last > .answers > .answer:last > .progress-custom > .progress-bar > .answer-count', text: '0'
  # end

  # it 'displays results for multiple choices question' do
  #   create_multiple_choices_survey
  #   login_and_go_to_reporting
  #
  #   assert_select '.question:first-of-type > .content-responses-count > .content', text: @question.content
  #   assert_select '.question:first-of-type > .content-responses-count > .responses-count', text: '1 Response'
  #   assert_select '.question:first-of-type > .answers > .answer:first-of-type > .answer-content', text: @question.possible_answers.first.content
  #   assert_select '.question:first-of-type > .answers > .answer:first-of-type > .progress-custom > .progress-bar > .answer-count', text: '1'
  #   assert_select '.question:first-of-type > .answers > .answer:last > .answer-content', text: @question.possible_answers.last.content
  #   assert_select '.question:first-of-type > .answers > .answer:last > .progress-custom > .progress-bar > .answer-count', text: '0'
  # end
  #
  # it 'displays results for free text question' do
  #   create_free_text_survey
  #   login_and_go_to_reporting
  #
  #   assert_select '.question:first > .content-responses-count > .content', text: @question.content
  #   assert_select '.question:first > .content-responses-count > .responses-count', text: '1 Response'
  #   assert_select "#words-cloud-#{@question.id}"
  # end

  private

  def create_multiple_choices_survey
    @udid        = '00000000-0000-4000-f000-000000000001'
    @user        = create(:admin)
    @survey      = create(:survey_with_one_multiple_question, account: @user.account)
    @device      = create(:device, udid: @udid)
    @question    = @survey.reload.questions.first

    @survey.update(live_at: 2.days.ago)

    @survey.reload

    10.times do
      create(:submission, device_id: @device.id, survey_id: @survey.id, udid: @udid, answers_count: 0)
    end

    create(:answer, question: @question, possible_answer: @question.possible_answers.first, submission: Submission.first)

    @survey.survey_stat.update(answers_count: 1)
  end

  def create_free_text_survey
    @udid        = '00000000-0000-4000-f000-000000000001'
    @user        = create(:admin)
    @survey      = create(:survey_with_one_free_question, account: @user.account)
    @device      = create(:device, udid: @udid)
    @question    = @survey.reload.questions.first

    @survey.update(live_at: 2.days.ago)

    @survey.reload

    10.times do
      create(:submission, device_id: @device.id, survey_id: @survey.id, udid: @udid, answers_count: 0)
    end

    create(:answer, question: @question, text_answer: 'test', submission: Submission.first)

    @survey.survey_stat.update(answers_count: 1)

    @survey.free_text_analyze!
  end

  def create_simple_survey
    @udid        = '00000000-0000-4000-f000-000000000001'
    @user        = create(:admin)
    @survey      = create(:survey, account: @user.account)
    @device      = create(:device, udid: @udid)

    @question = @survey.reload.questions.first

    @survey.update(live_at: 2.days.ago)

    @survey.reload

    10.times do
      create(:submission, device_id: @device.id, survey_id: @survey.id, udid: @udid, answers_count: 0)
    end

    create(:answer, question: @question, possible_answer: @question.possible_answers.first, submission: Submission.first)

    @survey.survey_stat.update(answers_count: 1)
  end

  def login_and_go_to_reporting
    post '/sign_in', params: { user: { email: @user.email, password: @user.password } }

    get "/surveys/#{@survey.id}/report"
  end
end
