# frozen_string_literal: true

require 'spec_helper'

describe KeywordMatchNotificationWorker do
  let(:keyword) { FFaker::Lorem.unique.word }

  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:question) { create(:question, survey: survey) }
  let(:answer) { create(:answer, question: question, text_answer: keyword) }

  context 'with no Automation' do
    it 'does not send notifications' do
      expect { described_class.new.perform(answer.id) }.not_to change { UserMailer.deliveries.count }
    end
  end

  context 'with Automations' do
    let(:email) { FFaker::Internet.email }

    before do
      @automation = create(:automation_with_condition_and_action, account: account)

      @automation_condition = @automation.conditions.first
      @automation_condition.update(condition: keyword)

      @automation_action = @automation.actions.first
      @automation_action.update(email: email)
    end

    context 'when no match is found due to unmatched question' do
      it 'does not send notifications' do
        unmatched_question = create(:question, survey: survey)
        @automation_condition.update(question: unmatched_question)

        expect { described_class.new.perform(answer.id) }.not_to change { UserMailer.deliveries.count }
      end
    end

    context 'when no match is found due to unmatched keyword' do
      it 'does not send notifications' do
        unmatched_keyword = FFaker::Lorem.unique.word
        @automation_condition.update(condition: unmatched_keyword)

        expect { described_class.new.perform(answer.id) }.not_to change { UserMailer.deliveries.count }
      end
    end

    context 'when no Automation is enabled' do
      it 'does not send notifications' do
        @automation.update(enabled: false)

        expect { described_class.new.perform(answer.id) }.not_to change { UserMailer.deliveries.count }
      end
    end

    context 'when an automation matched' do
      context 'when the automation has no emails' do
        it 'does not send notifications' do
          @automation_action.update(email: nil)

          expect { described_class.new.perform(answer.id) }.not_to change { UserMailer.deliveries.count }
        end
      end

      context 'with a question' do
        it 'sends notifications' do
          @automation_condition.update(question: question)

          expect { described_class.new.perform(answer.id) }.to change { UserMailer.deliveries.count }.by(1)
          expect(UserMailer.deliveries.first.to).to eq [email]
        end
      end

      context 'with no question' do
        it 'sends notifications' do
          expect { described_class.new.perform(answer.id) }.to change { UserMailer.deliveries.count }.by(1)
          expect(UserMailer.deliveries.first.to).to eq [email]
        end
      end
    end
  end
end
