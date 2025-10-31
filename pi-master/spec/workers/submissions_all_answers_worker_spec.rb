# frozen_string_literal: true
require 'spec_helper'

describe SubmissionsAllAnswersWorker do
  describe "azurity adverse event reporter" do
    let(:survey) { create(:survey, account: account) }
    let(:azurity_account_identifier) { "PI-62731489" }
    let(:submission_udid) { create(:submission, survey: survey, udid: SecureRandom.uuid).udid }

    context "when a text answer is present" do
      let(:question) { create(:free_text_question) }
      let(:text_answer) { FFaker::Lorem.sentence }

      before do
        custom_data = JSON.dump({})
        client_key = nil

        answers = [
          {
            "question_type" => "free_text_question",
            "question_id" => question.id,
            "answer" => text_answer
          }
        ]

        described_class.new.perform(account.identifier, submission_udid, answers, custom_data, client_key)
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
      let(:question) { create(:single_choice_question) }
      let(:text_answer) { nil }

      before do
        custom_data = JSON.dump({})
        client_key = nil

        answers = [
          {
            "question_type" => "single_choice_question",
            "question_id" => question.id,
            "possible_answer_id" => question.possible_answers.first.id
          }
        ]

        described_class.new.perform(account.identifier, submission_udid, answers, custom_data, client_key)
      end

      context "when the account belongs to azurity" do
        let(:account) { create(:account, identifier: azurity_account_identifier) }

        it "does not queue an azurity adverse event worker" do
          expect(Azurity::AzurityAdverseEventWorker).not_to have_enqueued_sidekiq_job
        end
      end
    end
  end
end
