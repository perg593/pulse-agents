# frozen_string_literal: true
require 'spec_helper'

describe SubmissionsAnswerWorker do
  before do
    Sidekiq::Worker.clear_all
    Answer.delete_all
  end

  after do
    Answer.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }

  describe "azurity adverse event reporter" do
    let(:azurity_account_identifier) { "PI-62731489" }
    let(:submission_udid) { create(:submission, survey: survey, udid: SecureRandom.uuid).udid }
    let(:survey) { create(:survey, account: account) }

    context "when a text answer is present" do
      let(:question) { create(:free_text_question, survey: survey) }
      let(:text_answer) { FFaker::Lorem.sentence }

      before do
        custom_data = JSON.dump({})
        possible_answer_ids = []

        described_class.new.perform(account.identifier, submission_udid, question.id, nil, text_answer, custom_data, possible_answer_ids, nil)
      end

      context "when the account belongs to azurity" do
        let(:account) { create(:account, identifier: azurity_account_identifier) }

        it "queues an azurity adverse event worker" do
          expect(Azurity::AzurityAdverseEventWorker).to have_enqueued_sidekiq_job(account.identifier, submission_udid)
        end
      end

      context "when the account does not belong to azurity" do
        let(:account) { create(:account) }

        it "does not queue an azurity adverse event worker" do
          expect(Azurity::AzurityAdverseEventWorker).not_to have_enqueued_sidekiq_job
        end
      end
    end

    context "when a text answer is not present" do
      let(:question) { create(:single_choice_question, survey: survey) }
      let(:text_answer) { nil }

      before do
        custom_data = JSON.dump({})
        possible_answer_ids = []
        possible_answer_id = question.possible_answers.first.id

        described_class.new.perform(account.identifier, submission_udid, question.id, possible_answer_id, text_answer, custom_data, possible_answer_ids, nil)
      end

      context "when the account belongs to azurity" do
        let(:account) { create(:account, identifier: azurity_account_identifier) }

        it "does not queue an azurity adverse event worker" do
          expect(Azurity::AzurityAdverseEventWorker).not_to have_enqueued_sidekiq_job
        end
      end
    end
  end

  it_behaves_like "favourite players reporter" do
    def worker_arguments(survey, submission, custom_data, question_id, text_answer)
      [
        survey.account.identifier,
        submission.udid,
        question_id,
        nil, # question.possible_answers.first.id It's a free-text question
        text_answer,
        custom_data,
        nil # client_key
      ]
    end
  end

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'creates an answer' do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.stop_showing_without_answer = true
    survey.save
    question = Question.last
    device = create(:device, udid: udid)
    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2, answers_count: 0)

    expect(Answer.count).to eq(0)

    described_class.new.perform(account.identifier, submission.udid, question.id, question.possible_answers.first.id, nil, {}, nil)

    expect(Answer.count).to eq(1)
  end

  it 'updates client_key if provided' do
    account = create(:account)
    survey = create(:survey)
    survey.account = account
    survey.stop_showing_without_answer = true
    survey.save
    question = Question.last
    device = create(:device, udid: udid)
    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2, answers_count: 0)

    expect(submission.client_key).to be_nil
    expect(device.client_key).to be_nil

    described_class.new.perform(account.identifier, submission.udid, question.id, question.possible_answers.first.id, nil, {}, nil, client_key)

    expect(submission.reload.client_key).to eq(client_key)
    expect(device.reload.client_key).to eq(client_key)
  end

  it 'updates survey answers_count' do
    account = create(:account)
    device = create(:device, udid: udid)

    survey = create(:survey)
    survey.account = account
    survey.stop_showing_without_answer = true
    survey.save
    survey.reload

    first_question = survey.questions[0]
    last_question = survey.questions[1]

    submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2, answers_count: 0)

    expect(survey.answers_count).to eq(0)

    described_class.new.perform(account.identifier, submission.udid, first_question.id, first_question.possible_answers.first.id, nil, {}, nil)

    expect(survey.reload.answers_count).to eq(1)

    described_class.new.perform(account.identifier, submission.udid, last_question.id, last_question.possible_answers.first.id, nil, {}, nil)

    expect(survey.reload.answers_count).to eq(1)
  end

  describe "WNBA favourite teams" do
    let(:braze_survey_id) { 6580 }
    let(:braze_question_id) { 20926 }
    let(:email_address) { FFaker::Internet.email }

    let(:device) { create(:device, udid: udid) }
    let(:submission) { create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2, answers_count: 0) }

    let(:question_id) { braze_question_id }
    let(:possible_answer_ids) { @favourite_teams_question.possible_answers.sort_by_position.pluck(:id) }
    let(:survey) { create(:survey_without_question, id: braze_survey_id, account: create(:account)) }

    before do
      @favourite_teams_question = create(:multiple_choices_question, survey: survey, id: braze_question_id)
      @other_question = create(:multiple_choices_question, survey: survey)

      described_class.new.perform(
        survey.account.identifier,
        submission.udid,
        question_id,
        nil,
        nil,
        JSON.dump({"email" => email_address }),
        possible_answer_ids
      )
    end

    context "when the submission is for the wnba survey" do
      context "when the submission is for the favourite teams question" do
        it "queues a favourite teams job" do
          expect(NBA::WNBAFavouriteTeamsWorker.jobs.size).to eq(1)
        end

        it "provides the expected arguments" do
          job_args = NBA::WNBAFavouriteTeamsWorker.jobs[0]["args"]

          expect(job_args).to contain_exactly(email_address, @favourite_teams_question.possible_answers.sort_by_position.pluck(:id), submission.udid)
        end
      end

      context "when the submission is not for the favourite teams question" do
        let(:question_id) { @other_question.id }
        let(:possible_answer_ids) { @other_question.possible_answers.sort_by_position.pluck(:id) }

        it "does not queue a favourite teams job" do
          expect(NBA::WNBAFavouriteTeamsWorker.jobs.size).to eq(0)
        end
      end
    end

    context "when the submission is not for the wnba survey" do
      let(:survey) { create(:survey_without_question, account: create(:account)) }

      it "does not queue a favourite teams job" do
        expect(NBA::WNBAFavouriteTeamsWorker.jobs.size).to eq(0)
      end
    end
  end

  describe "nba braze" do
    before do
      @braze_survey_id = 1132
      @survey = create(:survey_with_account, stop_showing_without_answer: true)
      @device = create(:device, udid: udid)
      @question = Question.last
    end

    it "queues a braze worker if this is a braze survey" do
      @survey.id = @braze_survey_id
      @survey.save

      submission = create(:submission, device_id: @device.id, survey_id: @survey.id, udid: udid2, answers_count: 0)

      described_class.new.perform(
        @survey.account.identifier,
        submission.udid,
        @question.id,
        @question.possible_answers.first.id,
        nil,
        JSON.dump({"email" => FFaker::Internet.email }),
        nil
      )

      expect(NBABrazeWorker.jobs.size).to eq(1)
    end

    it "does not queue a braze worker if this is not a braze survey" do
      submission = create(:submission, device_id: @device.id, survey_id: @survey.id, udid: udid2, answers_count: 0)

      described_class.new.perform(
        @survey.account.identifier,
        submission.udid,
        @question.id,
        @question.possible_answers.first.id,
        nil,
        JSON.dump({"email" => FFaker::Internet.email }),
        nil
      )

      expect(NBABrazeWorker.jobs.size).to eq(0)
    end

    it "does not queue a braze worker if the custom_data is nil" do
      @survey.id = @braze_survey_id
      @survey.save

      submission = create(:submission, device_id: @device.id, survey_id: @survey.id, udid: udid2, answers_count: 0)

      described_class.new.perform(
        @survey.account.identifier,
        submission.udid,
        @question.id,
        @question.possible_answers.first.id,
        nil,
        nil,
        nil
      )

      expect(NBABrazeWorker.jobs.size).to eq(0)
    end

    it "does not queue a braze worker if the custom_data did not include an e-mail address" do
      @survey.id = @braze_survey_id
      @survey.save

      submission = create(:submission, device_id: @device.id, survey_id: @survey.id, udid: udid2, answers_count: 0)

      described_class.new.perform(
        @survey.account.identifier,
        submission.udid,
        @question.id,
        @question.possible_answers.first.id,
        nil,
        JSON.dump({}),
        nil
      )

      expect(NBABrazeWorker.jobs.size).to eq(0)
    end
  end

  describe 'goal' do
    it 'automaticallies switch the status to completed once it reached the goal' do
      user = create(:user)
      account = user.account
      survey = create(:survey)
      survey.account = account
      survey.goal = 5
      survey.save
      survey.reload
      device = create(:device, udid: udid)

      # Live status
      expect(survey.reload.status).to eq('live')
      question = survey.questions.first

      5.times do |i|
        udid = "00000000-0000-4000-f000-00000000000#{i}"

        submission = create(:submission, device_id: device.id, survey_id: survey.id, udid: udid, answers_count: 0)

        described_class.new.perform(account.identifier, submission.udid, question.id, question.possible_answers.first.id, nil, {}, nil)

        if i < 4
          # Status should stay 'live' until it reaches the goal
          expect(survey.reload.status).to eq('live')
        else
          # Status should become 'complete' when it reaches the goal
          expect(survey.reload.status).to eq('complete')
        end
      end
    end
  end
end
