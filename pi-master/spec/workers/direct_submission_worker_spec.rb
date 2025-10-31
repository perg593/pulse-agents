# frozen_string_literal: true
require 'spec_helper'

describe DirectSubmissionWorker do
  before do
    Sidekiq::Worker.clear_all
    Device.delete_all
    Submission.delete_all
    Answer.delete_all

    @account         = create(:account)
    @survey          = create(:survey)
    @survey.account  = @account
    @survey.save
    @question = @survey.reload.questions.first
  end

  after do
    Device.delete_all
    Submission.delete_all
    Answer.delete_all
  end

  before :all do
    @udid            = '00000000-0000-4000-f000-000000000001'
    @custom_data     = {}
    @ip_address      = ''
    @user_agent      = ''
    @url             = ''
    @text_answer     = ''
  end

  it_behaves_like "favourite players reporter" do
    let(:udid)  { '00000000-0000-4000-f000-000000000001' }
    let(:url) { FFaker::Internet.uri("http") }
    let(:ip_address) { FFaker::Internet.ip_v4_address }
    let(:possible_answer_id) { nil } # this is a free text question
    let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:87.0) Gecko/20100101 Firefox/87.0" }

    def worker_arguments(survey, submission, custom_data, question_id, text_answer)
      [
        survey.account.identifier,
        udid,
        survey.id,
        url,
        ip_address,
        user_agent,
        custom_data,
        question_id,
        possible_answer_id,
        text_answer,
        submission.udid
      ]
    end
  end

  describe "azurity adverse event reporter" do
    let(:azurity_account_identifier) { "PI-62731489" }
    let(:submission_udid) { SecureRandom.uuid }
    let(:survey) { create(:survey, account: account) }

    let(:ip_address) { FFaker::Internet.ip_v4_address }
    let(:user_agent) { @user_agent }
    let(:custom_data) { @custom_data }
    let(:url) { @url }
    let(:device_udid) { SecureRandom.uuid }

    context "when a text answer is present" do
      let(:question) { create(:free_text_question, survey: survey) }
      let(:text_answer) { FFaker::Lorem.sentence }

      before do
        answer_id = nil

        described_class.new.perform(account.identifier, device_udid, survey.id,
                                    url, ip_address, user_agent, custom_data,
                                    question.id, answer_id, text_answer, submission_udid)
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
        answer_id = question.possible_answers.first.id
        ip_address = FFaker::Internet.ip_v4_address
        user_agent = @user_agent
        custom_data = @custom_data
        url = @url

        described_class.new.perform(account.identifier, device_udid, survey.id,
                                    url, ip_address, user_agent, custom_data,
                                    question.id, answer_id, text_answer, submission_udid)
      end

      context "when the account belongs to azurity" do
        let(:account) { create(:account, identifier: azurity_account_identifier) }

        it "does not queue an azurity adverse event worker" do
          expect(Azurity::AzurityAdverseEventWorker).not_to have_enqueued_sidekiq_job
        end
      end
    end
  end

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'returns a 404 error if the answer_id is invalid' do
    wrong_answer_id = 1234

    res = described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent, @custom_data, @question.id, wrong_answer_id,
                                      @text_answer)

    expect(res).to be_nil
  end

  it 'saves an answer' do
    expect(Answer.count).to eq(0)

    described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent, @custom_data, @question.id,
                                @question.possible_answers.first.id, @text_answer)

    expect(Answer.count).to eq(1)
    expect(Answer.first.question_id).to eq(@question.id)
    expect(Answer.first.possible_answer_id).to eq(@question.possible_answers.first.id)
  end

  it 'saves the text_answer' do
    question = create(:free_text_question, survey: @survey)

    question_id = @survey.questions.last.id
    empty_answer_id = nil
    text_answer = "I don't know"

    expect(Answer.count).to eq(0)

    described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent, @custom_data, question.id, empty_answer_id, text_answer)

    expect(Answer.count).to eq(1)
    expect(Answer.first.question_id).to eq(question_id)
    expect(Answer.first.text_answer).to eq("I don't know")
  end

  it 'saves a submission' do
    expect do
      Sidekiq::Testing.inline! do
        described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent,
                                    @custom_data, @question.id, @question.possible_answers.first.id, @text_answer)
      end
    end.to change { Submission.count }.by(1)

    submission = Submission.last
    expect(submission.survey_id).to eq(@survey.id)
    expect(submission.viewed_at).not_to be_nil
  end

  describe "nba braze" do
    let(:valid_custom_data) { JSON.dump({"email" => FFaker::Internet.email }) }
    let(:braze_survey_id) { 1132 }

    before do
      @survey = create(:survey, id: braze_survey_id, account: @account)
      @question = @survey.reload.questions.first
    end

    it "queues a braze worker if this is a braze survey" do
      described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent, valid_custom_data, @question.id,
                                  @question.possible_answers.first.id, @text_answer)

      expect(NBABrazeWorker.jobs.size).to eq(1)
    end

    # Fails intermittently. Fix in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1365
    # it "does not queue a braze worker if this is not a braze survey" do
    #   survey = create(:survey, account: @account)
    #   question = survey.reload.questions.first
    #
    #   described_class.new.perform(@account.identifier, @udid, survey.id, @url, @ip_address, @user_agent, valid_custom_data, question.id,
    #                               question.possible_answers.first.id, @text_answer)
    #
    #   expect(NBABrazeWorker.jobs.size).to eq(0)
    # end

    it "does not queue a braze worker if no e-mail address is provided" do
      custom_data = {}

      described_class.new.perform(@account.identifier, @udid, @survey.id, @url, @ip_address, @user_agent, custom_data, @question.id,
                                  @question.possible_answers.first.id, @text_answer)

      expect(NBABrazeWorker.jobs.size).to eq(0)
    end
  end
end
