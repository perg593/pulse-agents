# frozen_string_literal: true
require 'spec_helper'

describe PostAnswerWorker do
  let(:udid) { '00000000-0000-4000-f000-000000000001' }

  before do
    Sidekiq::Worker.clear_all
    Answer.delete_all

    @user            = create(:user)
    @account         = @user.account
    @survey          = create(:survey, goal: 1)
    @survey.account  = @account
    @survey.save
    @question        = @survey.reload.questions.first
    @possible_answer = @question.reload.possible_answers.first
    @submission_udid = SecureRandom.uuid
    @custom_data     = {}
    @ip_address      = ''
    @user_agent      = ''
    @url             = ''
    @text_answer     = ''

    @device          = create(:device, udid: udid)

    @submission      = create(:submission,
                              device_id: @device.id,
                              survey_id: @survey.id,
                              udid: @submission_udid,
                              answers_count: 1)

    @survey.survey_stat.update(answers_count: 1)
  end

  after do
    Answer.delete_all
  end

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'sets survey as completed when goal reached' do
    described_class.new.perform(@account.identifier, @submission_udid, @question.id, @question.possible_answers.first.id, '', nil)

    expect(@survey.reload.status).to eq 'complete'
  end

  it 'sends an email when goal reached' do
    described_class.new.perform(@account.identifier, @submission_udid, @question.id, @question.possible_answers.first.id, '', nil)

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to eq [@user.email]
    expect(mail.subject).to eq "#{@survey.account.name} Survey [#{@survey.name}] has reached its goal."
  end

  describe 'Filters' do
    describe '#optional_question_with_no_answer?' do
      context 'when a question is optional' do
        before do
          @question.update(optional: true)
        end

        context 'when there is no answer' do
          it 'does not create an answer' do
            described_class.new.perform(@account.identifier, @submission_udid, @question.id, nil, nil, nil)
            expect(Answer.count).to eq 0
          end
        end

        context 'when there is an answer' do
          it 'creates an answer' do
            described_class.new.perform(@account.identifier, @submission_udid, @question.id, @possible_answer.id, nil, nil)
            expect(Answer.count).to eq 1
          end
        end
      end

      context 'when a question is not optional' do
        before do
          @question.update(optional: false)
        end

        context 'when there is no answer' do
          it 'does not create an answer' do
            described_class.new.perform(@account.identifier, @submission_udid, @question.id, nil, nil, nil)
            expect(Answer.count).to eq 0
          end
        end

        context 'when there is an answer' do
          it 'creates an answer' do
            described_class.new.perform(@account.identifier, @submission_udid, @question.id, @possible_answer.id, nil, nil)
            expect(Answer.count).to eq 1
          end
        end
      end
    end
  end

  describe 'Answer Insertion' do
    let(:question) { survey.reload.questions.first }

    context 'when question_type is single_choice_question' do
      let(:survey) { create(:survey_with_one_question, account: @account) }

      it 'saves attributes' do
        possible_answer = question.reload.possible_answers.first
        submission = create(:submission, device_id: @device.id, survey_id: survey.id, udid: SecureRandom.uuid)

        described_class.new.perform(@account.identifier, submission.udid, question.id, possible_answer.id, nil, nil)

        answer = Answer.first
        expect(answer.submission_id).to eq submission.id
        expect(answer.question_id).to eq question.id
        expect(answer.question_type).to eq question.question_type
        expect(answer.possible_answer_id).to eq possible_answer.id
      end
    end

    context 'when question_type is free_text_question' do
      let(:survey) { create(:survey_with_one_free_question, account: @account) }

      it 'saves attributes' do
        submission = create(:submission, device_id: @device.id, survey_id: survey.id, udid: SecureRandom.uuid)

        text_answer = 'testtest'
        described_class.new.perform(@account.identifier, submission.udid, question.id, nil, text_answer, nil)

        answer = Answer.first
        expect(answer.submission_id).to eq submission.id
        expect(answer.question_id).to eq question.id
        expect(answer.question_type).to eq question.question_type
        expect(answer.text_answer).to eq text_answer
      end
    end

    context 'when question_type is multiple_choices_question' do
      let(:survey) { create(:survey_with_one_multiple_question, account: @account) }

      it 'saves attributes' do
        possible_answer_ids = question.reload.possible_answer_ids
        submission = create(:submission, device_id: @device.id, survey_id: survey.id, udid: SecureRandom.uuid)

        described_class.new.perform(@account.identifier, submission.udid, question.id, nil, nil, possible_answer_ids.join(', '))

        answer = Answer.first
        expect(answer.submission_id).to eq submission.id
        expect(answer.question_id).to eq question.id
        expect(answer.question_type).to eq question.question_type
        expect(Answer.pluck(:possible_answer_id)).to match_array(possible_answer_ids)
      end

      context 'when there are duplicates in possible answer ids' do
        let(:possible_answer_ids) { question.possible_answer_ids * 2 }

        it 'saves unique ones' do
          expected_answer_count = question.possible_answer_ids.count

          expect do
            described_class.new.perform(
              @account.identifier,
              create(:submission, device_id: @device.id, survey_id: survey.id).udid,
              question.id,
              nil,
              nil,
              possible_answer_ids.join(',')
            )
          end.to change { Answer.count }.from(0).to(expected_answer_count)

          expect(Answer.pluck(:possible_answer_id).uniq.count).to eq expected_answer_count
        end
      end
    end

    # Removed in https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2379
    context 'when question_type is slider_question' do
      let(:survey) { create(:survey_with_one_slider_question, account: @account) }

      it 'saves attributes' do
        possible_answer = question.reload.possible_answers.first
        submission = create(:submission, device_id: @device.id, survey_id: survey.id, udid: SecureRandom.uuid)

        described_class.new.perform(@account.identifier, submission.udid, question.id, possible_answer.id, nil, nil)

        answer = Answer.first
        expect(answer.submission_id).to eq submission.id
        expect(answer.question_id).to eq question.id
        expect(answer.question_type).to eq question.question_type
        expect(answer.possible_answer_id).to eq possible_answer.id
      end
    end
  end

  describe 'Personal Data Masking' do
    context 'when question type is text' do
      let(:question) { create(:question, question_type: :free_text_question, survey: @survey) }

      context 'when personal data masking is enabled' do
        it 'masks Social Security Numbers' do
          @account.personal_data_setting.update(masking_enabled: true)

          described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, 'foo 111-22-3333 bar', nil)

          text = Answer.first.text_answer
          expect(text).to eq('foo*****bar')
        end

        it 'masks UK national insurance' do
          @account.personal_data_setting.update(masking_enabled: true)

          described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, 'foo AA 123457 Bbar', nil)

          text = Answer.first.text_answer
          expect(text).to eq('foo*****bar')
        end

        context 'when phone masking is enabled' do
          it 'masks phone numbers' do
            @account.personal_data_setting.update(masking_enabled: true, phone_number_masked: true)

            described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, 'foo 01 822 7135 bar', nil)

            text = Answer.first.text_answer
            expect(text).to eq('foo*****bar')
          end
        end

        context 'when phone masking is disabled' do
          it 'does not mask phone numbers' do
            before_text = 'foo 01 822 7135 bar'

            described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, before_text, nil)

            after_text = Answer.first.text_answer
            expect(after_text).to eq(before_text)
          end
        end

        context 'when email masking is enabled' do
          it 'masks email addresses' do
            @account.personal_data_setting.update(masking_enabled: true, email_masked: true)

            described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, 'foo@bar.com', nil)

            text = Answer.first.text_answer
            expect(text).to eq('*****')
          end
        end

        context 'when email masking is disabled' do
          it 'does not mask email addresses' do
            before_text = 'foo@bar.com'

            described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, before_text, nil)

            after_text = Answer.first.text_answer
            expect(after_text).to eq(before_text)
          end
        end
      end

      context 'when personal data masking is disabled' do
        it 'does not mask personal data' do
          before_text = '000-11-2233 foo@bar.com 01 9399 9939'

          described_class.new.perform(@account.identifier, @submission_udid, question.id, nil, before_text, nil)

          after_text = Answer.first.text_answer
          expect(after_text).to eq(before_text)
        end
      end
    end
  end
end
